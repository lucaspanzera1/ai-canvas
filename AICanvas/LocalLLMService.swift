import Foundation
import llama

// MARK: - Prompt Format

enum PromptFormat {
    case chatml
    case llama3
    case phi3

    func buildPrompt(systemPrompt: String?, messages: [ChatMessage]) -> String {
        switch self {
        case .chatml:
            var p = ""
            if let sys = systemPrompt { p += "<|im_start|>system\n\(sys)<|im_end|>\n" }
            for msg in messages {
                let role = msg.role == .user ? "user" : "assistant"
                p += "<|im_start|>\(role)\n\(msg.content)<|im_end|>\n"
            }
            p += "<|im_start|>assistant\n"
            return p

        case .llama3:
            var p = "<|begin_of_text|>"
            if let sys = systemPrompt {
                p += "<|start_header_id|>system<|end_header_id|>\n\n\(sys)<|eot_id|>"
            }
            for msg in messages {
                let role = msg.role == .user ? "user" : "assistant"
                p += "<|start_header_id|>\(role)<|end_header_id|>\n\n\(msg.content)<|eot_id|>"
            }
            p += "<|start_header_id|>assistant<|end_header_id|>\n\n"
            return p

        case .phi3:
            var p = ""
            if let sys = systemPrompt { p += "<|system|>\n\(sys)<|end|>\n" }
            for msg in messages {
                let role = msg.role == .user ? "user" : "assistant"
                p += "<|\(role)|>\n\(msg.content)<|end|>\n"
            }
            p += "<|assistant|>\n"
            return p
        }
    }
}

// MARK: - Errors

enum LocalLLMError: LocalizedError {
    case modelLoadFailed(String)
    case contextCreationFailed
    case modelNotLoaded
    case decodeFailed
    case tokenizationFailed
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let path): return "Falha ao carregar modelo: \(path)"
        case .contextCreationFailed:     return "Falha ao criar contexto de inferência."
        case .modelNotLoaded:            return "Nenhum modelo local carregado. Baixe um modelo primeiro."
        case .decodeFailed:              return "Erro durante a inferência."
        case .tokenizationFailed:        return "Erro ao tokenizar o texto."
        case .notAvailable:              return "Inferência local não disponível."
        }
    }
}

// MARK: - Service

/// Actor that runs llama.cpp inference on-device using Metal acceleration.
actor LocalLLMService {
    static let shared = LocalLLMService()

    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var loadedModelPath: String?
    private var shouldCancel = false

    private init() {
        llama_backend_init()
    }

    var isModelLoaded: Bool { model != nil }

    func loadModel(at path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw LocalLLMError.modelLoadFailed(path)
        }
        if loadedModelPath == path { return }

        if let ctx = context { llama_free(ctx); context = nil }
        if let mdl = model { llama_free_model(mdl); model = nil }

        var mparams = llama_model_default_params()
        mparams.n_gpu_layers = 99  // offload all layers to Metal

        guard let mdl = llama_load_model_from_file(path, mparams) else {
            throw LocalLLMError.modelLoadFailed(path)
        }

        var cparams = llama_context_default_params()
        cparams.n_ctx   = 2048
        cparams.n_batch = 512

        guard let ctx = llama_new_context_with_model(mdl, cparams) else {
            llama_free_model(mdl)
            throw LocalLLMError.contextCreationFailed
        }

        model = mdl
        context = ctx
        loadedModelPath = path
    }

    func cancelGeneration() { shouldCancel = true }

    func generate(
        messages: [ChatMessage],
        systemPrompt: String?,
        format: PromptFormat = .chatml,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) -> AsyncThrowingStream<String, Error> {
        let prompt = format.buildPrompt(systemPrompt: systemPrompt, messages: messages)
        return AsyncThrowingStream { continuation in
            Task {
                self.shouldCancel = false
                do {
                    try await self.infer(
                        prompt: prompt,
                        maxTokens: maxTokens,
                        temperature: temperature,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private inference

    private func infer(
        prompt: String,
        maxTokens: Int,
        temperature: Float,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard let model, let context else { throw LocalLLMError.modelNotLoaded }

        llama_kv_cache_clear(context)

        // Tokenize prompt
        let nCtx = Int(llama_n_ctx(context))
        var tokens = [llama_token](repeating: 0, count: nCtx)
        let nPrompt: Int32 = prompt.withCString {
            llama_tokenize(model, $0, Int32(strlen($0)), &tokens, Int32(nCtx), true, false)
        }
        guard nPrompt > 0 else { throw LocalLLMError.tokenizationFailed }

        // Decode prompt in one batch
        var batch = llama_batch_init(nPrompt, 0, 1)
        defer { llama_batch_free(batch) }

        for i in 0..<Int(nPrompt) {
            batch.token[i]      = tokens[i]
            batch.pos[i]        = Int32(i)
            batch.n_seq_id[i]   = 1
            batch.seq_id[i]![0] = 0
            batch.logits[i]     = i == Int(nPrompt) - 1 ? 1 : 0
        }
        batch.n_tokens = nPrompt
        guard llama_decode(context, batch) == 0 else { throw LocalLLMError.decodeFailed }

        // Build sampler chain
        var sparams = llama_sampler_chain_default_params()
        guard let sampler = llama_sampler_chain_init(sparams) else {
            throw LocalLLMError.decodeFailed
        }
        defer { llama_sampler_free(sampler) }
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))

        // Autoregressive generation loop
        var nCur = Int(nPrompt)
        for _ in 0..<maxTokens {
            guard !shouldCancel else { break }

            let newToken = llama_sampler_sample(sampler, context, -1)
            llama_sampler_accept(sampler, newToken)

            if llama_token_is_eog(model, newToken) { break }

            // Decode token to UTF-8 piece
            var piece = [CChar](repeating: 0, count: 256)
            let len = llama_token_to_piece(model, newToken, &piece, 256, 0, false)
            if len > 0 {
                let bytes = piece.prefix(Int(len)).map { UInt8(bitPattern: $0) }
                if let text = String(bytes: bytes, encoding: .utf8), !text.isEmpty {
                    continuation.yield(text)
                }
            }

            // Prepare single-token batch for next step
            batch.n_tokens      = 1
            batch.token[0]      = newToken
            batch.pos[0]        = Int32(nCur)
            batch.n_seq_id[0]   = 1
            batch.seq_id[0]![0] = 0
            batch.logits[0]     = 1
            guard llama_decode(context, batch) == 0 else { throw LocalLLMError.decodeFailed }
            nCur += 1
        }
    }
}

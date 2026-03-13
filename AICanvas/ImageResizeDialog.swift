import SwiftUI
import UIKit

/// Wrapper SwiftUI para o diálogo de redimensionamento
struct ImageResizeDialogView: UIViewControllerRepresentable {
    let initialSize: CGSize
    let onResize: (CGSize) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = ImageResizeViewController(
            initialSize: initialSize,
            onResize: { size in
                onResize(size)
                dismiss()
            },
            onCancel: {
                onCancel()
                dismiss()
            }
        )
        return UINavigationController(rootViewController: controller)
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

/// Dialog UIViewController para redimensionar imagens com valores específicos
class ImageResizeViewController: UIViewController {
    let initialSize: CGSize
    let onResize: (CGSize) -> Void
    let onCancel: () -> Void
    
    private let widthTextField = UITextField()
    private let heightTextField = UITextField()
    private let aspectRatioSwitch = UISwitch()
    private let previewLabel = UILabel()
    
    private var currentWidth: CGFloat
    private var currentHeight: CGFloat
    private var aspectRatio: CGFloat
    
    init(initialSize: CGSize, onResize: @escaping (CGSize) -> Void, onCancel: @escaping () -> Void) {
        self.initialSize = initialSize
        self.onResize = onResize
        self.onCancel = onCancel
        self.currentWidth = initialSize.width
        self.currentHeight = initialSize.height
        self.aspectRatio = initialSize.height / max(initialSize.width, 1)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        title = "Redimensionar Imagem"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(handleCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(handleDone))
        
        view.backgroundColor = .systemBackground
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
        
        // Largura
        let widthContainer = createLabeledInput(
            label: "Largura (pt)",
            textField: widthTextField,
            value: String(Int(initialSize.width)),
            placeholder: "Largura"
        )
        stackView.addArrangedSubview(widthContainer)
        widthTextField.addTarget(self, action: #selector(widthChanged), for: .editingChanged)
        
        // Altura
        let heightContainer = createLabeledInput(
            label: "Altura (pt)",
            textField: heightTextField,
            value: String(Int(initialSize.height)),
            placeholder: "Altura"
        )
        stackView.addArrangedSubview(heightContainer)
        heightTextField.addTarget(self, action: #selector(heightChanged), for: .editingChanged)
        
        // Proporção de Aspecto
        let aspectContainer = UIView()
        aspectContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let aspectLabel = UILabel()
        aspectLabel.text = "Manter proporção"
        aspectLabel.font = .systemFont(ofSize: 16, weight: .medium)
        aspectLabel.translatesAutoresizingMaskIntoConstraints = false
        aspectContainer.addSubview(aspectLabel)
        
        aspectRatioSwitch.isOn = true
        aspectRatioSwitch.translatesAutoresizingMaskIntoConstraints = false
        aspectContainer.addSubview(aspectRatioSwitch)
        
        NSLayoutConstraint.activate([
            aspectLabel.leadingAnchor.constraint(equalTo: aspectContainer.leadingAnchor),
            aspectLabel.centerYAnchor.constraint(equalTo: aspectContainer.centerYAnchor),
            
            aspectRatioSwitch.trailingAnchor.constraint(equalTo: aspectContainer.trailingAnchor),
            aspectRatioSwitch.centerYAnchor.constraint(equalTo: aspectContainer.centerYAnchor),
            
            aspectContainer.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        stackView.addArrangedSubview(aspectContainer)
        
        // Preview
        previewLabel.text = "Tamanho: \(Int(initialSize.width)) × \(Int(initialSize.height)) pt"
        previewLabel.font = .systemFont(ofSize: 14, weight: .regular)
        previewLabel.textColor = .secondaryLabel
        previewLabel.textAlignment = .center
        stackView.addArrangedSubview(previewLabel)
        
        stackView.setCustomSpacing(40, after: aspectContainer)
    }
    
    private func createLabeledInput(label: String, textField: UITextField, value: String, placeholder: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 16, weight: .medium)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(labelView)
        
        textField.borderStyle = .roundedRect
        textField.placeholder = placeholder
        textField.text = value
        textField.keyboardType = .numberPad
        textField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textField)
        
        NSLayoutConstraint.activate([
            labelView.topAnchor.constraint(equalTo: container.topAnchor),
            labelView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            textField.topAnchor.constraint(equalTo: labelView.bottomAnchor, constant: 8),
            textField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textField.heightAnchor.constraint(equalToConstant: 44),
            
            container.bottomAnchor.constraint(equalTo: textField.bottomAnchor)
        ])
        
        return container
    }
    
    @objc private func widthChanged() {
        guard let text = widthTextField.text,
              let dbl = Double(text) else { return }
        let value = CGFloat(dbl)
        currentWidth = max(40, value)
        if aspectRatioSwitch.isOn {
            currentHeight = currentWidth * aspectRatio
            heightTextField.text = String(Int(currentHeight))
        }
        updatePreview()
    }
    
    @objc private func heightChanged() {
        guard let text = heightTextField.text,
              let dbl = Double(text) else { return }
        let value = CGFloat(dbl)
        currentHeight = max(40, value)
        if aspectRatioSwitch.isOn {
            currentWidth = currentHeight / aspectRatio
            widthTextField.text = String(Int(currentWidth))
        }
        updatePreview()
    }
    
    private func updatePreview() {
        previewLabel.text = "Tamanho: \(Int(currentWidth)) × \(Int(currentHeight)) pt"
    }
    
    @objc private func handleDone() {
        let newSize = CGSize(width: currentWidth, height: currentHeight)
        onResize(newSize)
    }
    
    @objc private func handleCancel() {
        onCancel()
    }
}

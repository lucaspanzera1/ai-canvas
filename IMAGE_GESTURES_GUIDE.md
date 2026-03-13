# 📸 Guia de Gestos para Imagens no AICanvas

As funcionalidades de redimensionamento e exclusão de imagens foram completamente melhoradas! 

## ✨ Como Usar

### **Seleção (Tap Único)**
**Gesto:** Toque uma vez na imagem
**O que acontece:** 
- A imagem fica selecionada (borda azul tracejada aparece)
- Handles (quadrados) nos cantos aparecem
- Você recebe feedback tátil

### **Arrastar (Pan)**
**Gesto:** Mantenha um dedo pressionado e arraste
**O que acontece:** 
- A imagem se move acompanhando o seu dedo
- A opacidade muda levemente durante o arrasto
- Quando você solta, a imagem fica no novo local

### **Redimensionar (Pinch)**
**Gesto:** Dois dedos afastando ou aproximando na imagem
**O que acontece:** 
- A imagem aumenta (dedos afastando) ou diminui (dedos aproximando)
- O tamanho é respeitado mantendo a proporção
- A imagem acompanha o zoom do canvas

### **Deletar (Duplo Tap)**
**Gesto:** Toque duas vezes rapidamente na imagem
**O que acontece:** 
- Animação de desaparecimento suave (diminuindo de tamanho)
- Feedback tátil de sucesso
- A imagem é removida do canvas

### **Menu de Contexto (Long Press)**
**Gesto:** Mantenha o dedo pressionado por ~0.4 segundos
**O que aparece:** Menu com opções:
- **Copiar** - Copia a imagem para a área de transferência
- **Redimensionar** - Abre diálogo para definir tamanho específico
- **Camadas** - Traz para frente ou envia para trás
- **Duplicar** - Cria uma cópia da imagem
- **Deletar** - Remove a imagem

## 🎯 Dicas Rápidas

| Ação | Gesto | Resultado |
|------|-------|-----------|
| Selecionar | 1 tap | Mostra borda e handles |
| Mover | Arrastar | Move a imagem |
| Redimensionar | Pinch (2 dedos) | Aumenta/diminui |
| Deletar rápido | 2 taps | Animação de saída |
| Menu completo | Long press | Abre menu de opções |

## 💡 Modos de Redimensionamento

### Opção 1: Pinch (Direto)
Ideal para ajustes rápidos visualmente

### Opção 2: Menu > Redimensionar
Para valores precisos em pontos (pt)

## 🎨 Feedback Visual

- **Seleção:** Borda azul tracejada com sombra
- **Handles:** Quadrados azuis nos cantos (com sombra)
- **Arrasto:** Opacidade muda levemente
- **Interações:** Haptic feedback em cada ação

## ⚡ Performance

As imagens agora:
- Respondem muito mais rápido aos gestos
- Sincronizam perfeitamente com o zoom do canvas
- Não conflitam com outros gestos do canvas
- Mantêm seu tamanho e posição ao fazer zoom na página

---

**Nota:** Todas as ações têm feedback tátil e visual para melhor experiência do usuário.

# Spine Viewer

Visualizador de animações Spine para validação antes de envio.  
Compilado com Godot 4.6 + spine-godot (mesma versão dos jogos).

## Como usar (para o animador)

### 1. Adicionar seus arquivos

Coloque os arquivos exportados do Spine na pasta:

```
Godot/assets/spine/viewer/
```

Formatos aceitos:
- `.spine-json` — skeleton exportado como JSON (recomendado)
- `.skel` — skeleton binário
- `.atlas` — atlas gerado pelo Spine
- `.png` — textura(s) da sprite sheet

### 2. Commit & Push

Faça commit dos arquivos e push para a branch `main`.

```bash
git add Godot/assets/spine/viewer/
git commit -m "feat: adiciona animação X para revisão"
git push
```

Ou use a interface web do GitHub: navegue até a pasta e clique em **Add file → Upload files**.

### 3. Aguardar o build (~3 minutos)

O CI compila e publica automaticamente. Acompanhe em **Actions**.

### 4. Validar no browser

Acesse a URL do GitHub Pages e valide:
- ✅ Animações reproduzem corretamente
- ✅ Transições entre animações funcionam
- ✅ Escala e posição corretas
- ✅ Loop / sem loop conforme esperado

### Controles

| Ação | Como |
|---|---|
| Mover personagem | Arraste com o mouse |
| Zoom | Scroll do mouse |
| Resetar posição | Botão ⟳ Reset |
| Trocar animação | Dropdown no rodapé |
| Play / Pause / Stop | Botões ▶ ⏸ ⏹ |
| Loop on/off | Botão 🔁 |
| Velocidade | Slider |

## Para o desenvolvedor

A pasta `Godot/assets/spine/demo/` pode conter uma animação de exemplo sempre visível quando `viewer/` estiver vazia.

Estrutura da extension Spine: `Godot/bin/` (copiado do projeto principal).

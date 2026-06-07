# Spine Viewer

Visualizador de animações Spine para validação antes de envio ao desenvolvedor.
Compilado com Godot 4.6 + spine-godot (mesma versão usada nos jogos de produção).

<<<<<<< Updated upstream

=======
O animador **não precisa instalar nada** — abre a URL no browser, seleciona os arquivos do PC e valida a animação.

---

## Para o animador

### 1. Abrir o visualizador

Acesse a URL do GitHub Pages do projeto (ex: `https://<org>.github.io/SpineViewer`).

### 2. Carregar os arquivos

Clique em **📂 Carregar Spine** na barra inferior e selecione simultaneamente:

| Arquivo | Extensão | Obrigatório |
|---|---|---|
| Skeleton | `.spine-json` ou `.skel` | Sim |
| Atlas | `.atlas` | Sim |
| Textura(s) | `.png` ou `.webp` | Sim |

> Selecione todos os arquivos de uma vez no seletor — o viewer monta o conjunto automaticamente.

### 3. Controles

| Ação | Como |
|---|---|
| Mover personagem | Clique e arraste com o mouse |
| Zoom | Scroll do mouse |
| Resetar posição/escala | Botão **⟳ Reset** |
| Trocar animação | Dropdown no rodapé |
| Play | Botão **▶** |
| Pause | Botão **⏸** |
| Stop (volta ao setup pose) | Botão **⏹** |
| Loop on/off | Botão **🔁** (opaco = ativo) |
| Velocidade | Slider — de 0.1× a 3.0× |

### 4. Checklist de validação

Antes de enviar os arquivos ao desenvolvedor, confirme:

- [ ] Todas as animações do projeto aparecem no dropdown
- [ ] Cada animação reproduz corretamente (sem distorções, sem ossos faltando)
- [ ] Transições entre animações funcionam (teste trocando no dropdown durante a reprodução)
- [ ] Escala e proporções estão corretas em relação ao tamanho esperado no jogo
- [ ] Loop funciona sem saltos visíveis nas animações marcadas como loop
- [ ] Velocidade normal (1.0×) parece adequada

---

## Para o desenvolvedor

### Estrutura do projeto

```
SpineViewer/
├── Godot/
│   ├── Scenes/
│   │   └── main.tscn               ← cena raiz (apenas um Control + script)
│   ├── Scripts/
│   │   └── main.gd                 ← toda a lógica (UI, carregamento, controles)
│   ├── assets/
│   │   └── spine/
│   │       └── demo/               ← animação de exemplo (desktop/editor only)
│   ├── bin/                        ← spine-godot extension (copiado do projeto principal)
│   │   ├── spine_godot_extension.gdextension
│   │   ├── web/                    ← wasm para export web
│   │   ├── linux/
│   │   ├── windows/
│   │   └── ...
│   ├── project.godot
│   └── export_presets.cfg          ← Web export, extensions_support=true
├── dist/                           ← gerado pelo CI (ignorado pelo git)
├── .github/
│   └── workflows/
│       └── pages.yml               ← build + deploy GitHub Pages
└── README.md
```

### Como funciona o carregamento de arquivos (web)

O Godot Web não tem acesso ao filesystem do usuário. O fluxo é:

1. `_open_file_picker()` injeta JavaScript via `JavaScriptBridge.eval()` — cria um `<input type="file">` oculto
2. O JS lê cada arquivo como `ArrayBuffer` e converte para Base64
3. Quando todos os arquivos estão prontos, seta `window._spineReady = true` e `window._spineFiles = {nome: base64}`
4. `_process()` faz polling de `window._spineReady` a cada frame
5. `_handle_web_files()` decodifica o Base64 com `Marshalls.base64_to_raw()` e grava em `user://spine/`
6. `_load_spine()` carrega os recursos via `ResourceLoader.load()` com `CACHE_MODE_IGNORE`
7. Os nós Spine são instanciados com `ClassDB.instantiate("SpineSprite")` e `ClassDB.instantiate("SpineSkeletonDataResource")` — evita erro de parse em modo headless onde a extension não está disponível

### Atualizar a extension Spine

Quando atualizar a versão do spine-godot nos projetos de jogo, copie os binários para este repo:

```bash
cp -r <projeto>/Godot/bin/ SpineViewer/Godot/bin/
```

Confirme que `export_presets.cfg` mantém `variant/extensions_support=true`.

### Build local

```bash
# Verificar erros de script:
cd Godot && godot --headless --quit

# Exportar web manualmente:
mkdir -p dist
godot --headless --path Godot --export-release "Web" ../dist/index.html
```

### CI/CD

Push para `main` dispara `.github/workflows/pages.yml`:

1. Download do Godot 4.6-stable (Linux headless)
2. Download e instalação dos export templates oficiais
3. `godot --headless --export-release "Web"` → `dist/`
4. Deploy para GitHub Pages via `actions/deploy-pages`

Tempo médio de build: ~3–4 minutos.

> O workflow usa `godot-builds` (releases oficiais do Godot). Se a versão mudar, atualize as duas URLs no `pages.yml`.
>>>>>>> Stashed changes

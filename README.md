# Dayz Wallpapers

Seletor de wallpapers para **DankMaterialShell 1.4.6+**: carrossel inclinado,
categorias por pasta e troca automática aleatória ou em sequência.
Código original de Matheuscara, desenvolvido com ajuda de IA (Codex). Licença MIT.

![Prévia ilustrativa do seletor](docs/preview.png)

**[Instalar](#instalar-no-nix--um-comando)** · [Categorias](#organizar-as-categorias) ·
[Agendamento](#agendamento-e-monitores) · [NixOS](#nixos-declarativo) ·
[Diagnóstico](#resolver-problemas)

## Recursos e requisitos

| Recurso | Comportamento |
|---|---|
| Navegação | Carrossel com setas, roda do mouse, Enter para aplicar e Esc para fechar |
| Categorias | Geradas a partir das pastas e subpastas da coleção local |
| Troca automática | Categoria, ordem aleatória ou sequencial e intervalo de 1 a 1440 minutos |
| Vários monitores | Integração com a seleção de monitor do DMS |
| Integração | Comandos IPC para abrir, atualizar, consultar e programar |
| Instalação | Nix, módulo NixOS, Home Manager ou checkout com Python 3 |

Requer **DMS 1.4.6+** funcionando. Os pacotes Nix são definidos para
`x86_64-linux` e `aarch64-linux`; o modo sem Nix requer Python 3 no ambiente do DMS.
A troca usa o próprio DMS e não exige um serviço adicional de wallpaper.

O projeto distribui o seletor. As imagens são fornecidas por você. Nesta versão,
as categorias seguem a estrutura de pastas; o filtro por proporção/ultrawide ainda
não está disponível.

## Instalar no Nix — um comando

Com Nix e DMS já instalados, execute como seu usuário, **sem sudo**:

```bash
nix run github:Matheuscara/dayzWallpapers
```

O instalador inclui Python, instala o plugin no diretório do usuário e tenta
habilitá-lo no DMS em execução. Não precisa clonar o repositório, instalar Python
manualmente ou fazer rebuild do NixOS. Mantém uma raiz de garbage collection em
`~/.local/state/dayzWallpapers/current` para o plugin e Python continuarem presentes
após `nix-collect-garbage`. Respeita `XDG_CONFIG_HOME` e `XDG_STATE_HOME`.

Para conferir sem instalar:

```bash
nix run github:Matheuscara/dayzWallpapers -- --dry-run
```

Para atualizar/substituir uma instalação existente, guardando backup:

```bash
nix run --refresh github:Matheuscara/dayzWallpapers -- --replace
```

O backup fica em `~/.config/DankMaterialShell/backups/`. Configurações pessoais são
preservadas. Atualizações de QML podem exigir reiniciar o DMS; o instalador não
reinicia sua sessão. Se o DMS estiver fechado, abra-o e habilite **Wallpapers**
em Configurações → Plugins. `--no-enable` instala sem tentar habilitar.

Se Nix reclamar de recursos experimentais, use o prefixo
`nix --extra-experimental-features 'nix-command flakes' run ...`.
Este projeto instala um plugin; a instalação do DMS/compositor é pré-requisito.

## Abrir e configurar

```bash
dms ipc call dayzWallpapers toggle
```

Em Configurações → Plugins → Wallpapers, escolha sua pasta. Por padrão usa
`~/Pictures/Wallpapers`. Cada subpasta vira uma categoria. O download de wallpapers
não faz parte do instalador; imagens e configurações pessoais não são distribuídas.

Exemplo de atalho Niri, dentro de `binds`:

```kdl
Mod+Ctrl+W { spawn "dms" "ipc" "call" "dayzWallpapers" "toggle"; }
```

[Detalhes de uso e IPC](plugin/README.md).

## Organizar as categorias

Exemplo de coleção:

```text
~/Pictures/Wallpapers/
├── Natureza/
│   ├── Florestas/
│   └── Montanhas/
├── Cidades/
├── Espaco/
├── Abstrato/
├── Anime/
└── imagem-avulsa.jpg
```

**Todas** reúne a coleção; **Arquivos soltos** mostra as imagens na raiz.
Subpastas conservam o caminho relativo, como `Natureza/Montanhas`. Depois de copiar
imagens ou reorganizar as pastas, use **Atualizar** no seletor.

A indexação é limitada a **10 mil imagens** e ocorre ao abrir, atualizar e antes
de trocar. Arquivos ocultos, diretórios simbólicos e links para fora da coleção
são ignorados; links para a mesma imagem são deduplicados. O campo
`excludedFolders` permite ignorar pastas agregadoras. Não há monitoramento
constante das pastas nem download automático de imagens.

## Agendamento e monitores

1. Abra **Agendar troca** e escolha a categoria.
2. Escolha ordem aleatória ou sequencial e intervalo de 1 a 1440 minutos.
3. Ative a programação; use **Pausar** para interromper.

A programação começa **desligada**. Quando ativada, continua com o seletor fechado,
enquanto o DMS estiver em execução. A categoria programada permanece independente
da categoria que você visitar depois. Reiniciar o DMS reinicia a contagem do intervalo.

Ativar a programação pausa a rotação nativa do DMS para evitar duas trocas
concorrentes. Pausar este plugin não reativa a rotação nativa automaticamente.

No modo de wallpaper por monitor, a programação preserva a tela selecionada ao
ativar. Se ela desconectar, o plugin informa erro e tenta novamente no próximo
intervalo, mantendo as outras telas.

### Comandos IPC

```bash
dms ipc call dayzWallpapers status
dms ipc call dayzWallpapers refresh
dms ipc call dayzWallpapers pause
dms ipc call dayzWallpapers schedule 30 "Natureza/Montanhas" random
```

`schedule` recebe intervalo em minutos, categoria relativa à coleção e ordem
(`random` ou `sequential`). Para todas as categorias, passe `""` como segundo
argumento. `status` mostra a contagem, a programação e erros.

## NixOS declarativo

Adicione o input ao seu flake:

```nix
inputs.dayzWallpapers.url = "github:Matheuscara/dayzWallpapers";
```

Inclua `inputs.dayzWallpapers.nixosModules.default` em `modules`, junto do módulo
NixOS do DMS que fornece `programs.dms-shell.plugins`. Depois faça seu rebuild
normal e habilite o plugin pela interface do DMS. Python já está incluído no pacote.
O módulo não instala nem habilita o DMS por conta própria.

Para Home Manager, importe `inputs.dayzWallpapers.homeManagerModules.default`.
Ele instala a mesma versão empacotada via `xdg.configFile`.

Escolha **uma** forma de instalação por máquina. Antes de migrar do instalador
para um módulo, desabilite o plugin, guarde/remova somente o link de instalação
manual `~/.config/DankMaterialShell/plugins/DayzWallpapers` e depois aplique o módulo.
As preferências do DMS ficam em outro arquivo e são preservadas. Não importe também
o módulo da coleção dayzWidgets contendo o mesmo plugin.

## Sem Nix

```bash
git clone https://github.com/Matheuscara/dayzWallpapers.git
cd dayzWallpapers
python3 scripts/install.py
```

Nesse modo, mantenha o checkout no disco e Python 3 disponível no PATH do DMS.
Para atualizar esse checkout, preserve eventuais alterações locais, execute
`git pull --ff-only` e recarregue o DMS. Se mover o checkout, execute novamente o
instalador com `--replace` para atualizar o link.

Dayz Wallpapers também está disponível na
[coleção dayzWidgets](https://github.com/Matheuscara/dayzWidgets). As duas formas
usam o mesmo ID de plugin; mantenha uma única instalação.

## Remover

Desabilite o plugin na interface do DMS. Remova somente o link
`~/.config/DankMaterialShell/plugins/DayzWallpapers` e a raiz
`~/.local/state/dayzWallpapers/current` criados pelo instalador. Backups e
configurações pessoais podem ser mantidos. Se usou um módulo, retire sua importação
e aplique novamente o NixOS/Home Manager.

## Resolver problemas

| Sintoma | O que conferir |
|---|---|
| Nix reclama de flakes | Habilite `nix-command` e `flakes`, ou use o prefixo indicado na instalação |
| Plugin não aparece | Abra/recarregue o DMS e habilite **Wallpapers** em Configurações → Plugins |
| Diretório de instalação já existe | Escolha uma origem; no instalador, `--replace` faz backup antes de substituir |
| Coleção vazia | Confira o caminho configurado, as permissões e se as imagens estão dentro da coleção; use Atualizar |
| Imagem nova não aparece | Use Atualizar; confira exclusões, links simbólicos e o limite de indexação |
| Python não encontrado | No checkout, disponibilize Python 3 no PATH do DMS; o pacote Nix já o inclui |
| Programação não troca | Consulte `status`, confirme que o DMS está aberto e que o monitor alvo está conectado |

Para relatar um problema, informe versão do DMS, compositor, método de instalação,
saída de `status` e passos para reproduzir, removendo dados pessoais.

## Estrutura e desenvolvimento

| Caminho | Responsabilidade |
|---|---|
| [plugin/](plugin/) | Interface QML, configurações, manifesto e indexador Python |
| [plugin/README.md](plugin/README.md) | Referência de uso e IPC |
| [scripts/install.py](scripts/install.py) | Instalação, backup e habilitação via IPC |
| [flake.nix](flake.nix) | Pacotes, instalador e módulos NixOS/Home Manager |
| [tests/](tests/) | Testes automatizados |

### Verificar o projeto

```bash
python3 -m unittest discover -s tests -v
nix build .#plugin
nix flake check
```

Esses comandos verificam testes e empacotamento; o funcionamento visual precisa
ser conferido em uma sessão DMS compatível.

## Licença

[MIT](LICENSE). Código original de Matheuscara. A prévia é ilustrativa; imagens e
preferências pessoais não fazem parte da instalação.

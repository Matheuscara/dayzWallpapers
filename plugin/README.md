# Dayz Wallpapers

Seletor de wallpapers locais para **DankMaterialShell 1.4.6+**, criado por
Matheuscara. Código original MIT, sem incorporar o código do Wallpaper Carousel.
O carrossel inclinado é uma referência de interação; este plugin tem implementação
própria, categorias por pasta e agendamento persistente. Requer Python 3.

## Usar

Instale a pasta, habilite `dayzWallpapers` e abra:

```bash
dms ipc call dayzWallpapers toggle
```

Em Configurações → Plugins, escolha a pasta absoluta das coleções. O padrão é
`~/Pictures/Wallpapers`. Cada pasta vira uma categoria; subpastas preservam seu
caminho. Arquivos na raiz aparecem em **Arquivos soltos**. **Todas** reúne a coleção.
O botão **Atualizar** encontra imagens novas. Links duplicados são deduplicados;
links para fora da coleção, diretórios simbólicos e arquivos ocultos são ignorados.
Pastas agregadoras podem ser ignoradas pelo campo `excludedFolders`.

- Clique em uma categoria para filtrar.
- Use as setas ou a roda do mouse para navegar.
- Clique na imagem central ou em **Aplicar**; Enter também aplica e Esc fecha.
- **Aleatório agora** escolhe outra imagem da categoria, quando houver mais de uma.
- **Agendar troca** permite escolher categoria, ordem aleatória/em sequência e
  intervalo inteiro de 1 a 1440 minutos. **Ativar** inicia; **Pausar** interrompe.

A categoria agendada é independente da categoria visitada depois. O timer continua
com o seletor fechado e retoma com um intervalo completo ao recarregar o DMS.
Fica desligado por padrão e não troca nada ao iniciar ou ao abrir o menu.
Ao ativar uma programação, pausa a troca automática nativa do DMS para evitar
dois temporizadores concorrentes. Pausar este plugin mantém as trocas interrompidas.
A troca usa SessionData do DMS; não requer swww/swaybg, rede, cron ou systemd adicional.
Com wallpaper por monitor, preserva a tela escolhida ao ativar; se ela desconectar,
mostra erro e tenta novamente no próximo intervalo, sem mudar outra tela.

A indexação é feita ao abrir/atualizar e antes de trocar, limitada a 10 mil imagens.
Não há polling constante das pastas. As miniaturas usam CachingImage do DMS e seu cache local, carregado sob demanda.
Escolhas manuais são validadas novamente antes da aplicação para lidar com arquivos
removidos. Nenhuma configuração ou imagem pessoal é distribuída.

## IPC

```bash
dms ipc call dayzWallpapers status
dms ipc call dayzWallpapers refresh
dms ipc call dayzWallpapers pause
dms ipc call dayzWallpapers collection /caminho/Wallpapers Galeria
dms ipc call dayzWallpapers schedule 30 "" random
```

`schedule` recebe minutos, caminho relativo da categoria (vazio = Todas) e
`random` ou `sequential`. A programação só funciona enquanto o DMS estiver aberto.
`status` informa contagem, programação e erros; não retorna um catálogo de arquivos.

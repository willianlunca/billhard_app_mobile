# billhard_app_mobile

App Mobile Billhard.

## Getting Started

# AutomotiveManager

O `AutomotiveManager` é responsável por gerenciar a integração do aplicativo BillHard com:

* Apple CarPlay
* Android Auto

Ele permite:

* Adicionar equipamentos ao veículo.
* Separar equipamentos por menu.
* Remover equipamentos.
* Atualizar informações recebidas por MQTT ou HTTP.
* Mover equipamentos entre menus.
* Identificar quando o usuário toca em um card no veículo.
* Consultar quais cards estão atualmente selecionados.

---

# 1. Instância do gerenciador

O `AutomotiveManager` utiliza o padrão singleton. Isso significa que existe uma única instância durante toda a execução do aplicativo.

Para acessar o gerenciador:

```dart
final AutomotiveManager automotiveManager =
    AutomotiveManager.instance;
```

Também é possível acessar diretamente:

```dart
AutomotiveManager.instance;
```

---

# 2. Menus disponíveis

Todo card precisa pertencer a um menu.

Os menus disponíveis são:

```dart
AutomotiveMenu.residencial
AutomotiveMenu.comercial
AutomotiveMenu.industrial
```

Exemplo:

```dart
final menu = AutomotiveMenu.comercial;
```

Para obter o nome do menu:

```dart
debugPrint(menu.titulo);
```

Resultado:

```text
Comercial
```

---

# 3. Inicializar o gerenciador

A inicialização normalmente é feita no `main.dart`.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AutomotiveManager.instance.inicializar(
    onCardPressed: (evento) {
      debugPrint(
        'Card clicado: ${evento.card.titulo}',
      );
    },
  );

  runApp(const BillhardApp());
}
```

## Callback de clique

O parâmetro `onCardPressed` é chamado quando o usuário toca em um card no CarPlay ou Android Auto.

```dart
await AutomotiveManager.instance.inicializar(
  onCardPressed: (evento) {
    debugPrint(evento.card.id);
    debugPrint(evento.card.titulo);
    debugPrint(evento.card.descricao);
    debugPrint(evento.card.menu.titulo);
    debugPrint(evento.plataforma);
    debugPrint(evento.dataHora.toString());
  },
);
```

O evento contém:

```dart
evento.card
evento.plataforma
evento.dataHora
```

O card contém:

```dart
evento.card.id
evento.card.titulo
evento.card.descricao
evento.card.menu
evento.card.serialNumber
```

---

# 4. Estrutura de um card

Um card é representado por `AutomotiveCardData`.

```dart
final card = AutomotiveCardData(
  id: 'TK-C-0001',
  titulo: 'Câmara Fria 01',
  descricao: 'Temperatura: 4 °C',
  serialNumber: 'TK-C-0001',
  menu: AutomotiveMenu.comercial,
);
```

## Campos

### `id`

Identificador único usado para localizar, atualizar e remover o card.

```dart
id: 'TK-C-0001'
```

O ideal é utilizar o número de série do equipamento como `id`.

### `titulo`

Nome principal exibido no card.

```dart
titulo: 'Câmara Fria 01'
```

### `descricao`

Informação secundária exibida abaixo do título.

```dart
descricao: 'Temperatura: 4 °C'
```

Também pode conter várias informações:

```dart
descricao: '4 °C • 68% • Online'
```

### `serialNumber`

Número de série do equipamento.

```dart
serialNumber: 'TK-C-0001'
```

Este campo é opcional.

### `menu`

Menu no qual o card será exibido.

```dart
menu: AutomotiveMenu.comercial
```

---

# 5. Adicionar um card

Existem duas formas principais de adicionar um card.

## 5.1 Adicionar passando os valores separadamente

```dart
await AutomotiveManager.instance.adicionarCard(
  id: 'TK-C-0001',
  titulo: 'Câmara Fria 01',
  descricao: 'Temperatura: 4 °C',
  serialNumber: 'TK-C-0001',
  menu: AutomotiveMenu.comercial,
);
```

Esse método é útil quando os dados vêm diretamente de uma variável, banco de dados ou resposta HTTP.

Exemplo com objeto do equipamento:

```dart
await AutomotiveManager.instance.adicionarCard(
  id: equipamento.serialNumber,
  titulo: equipamento.nome,
  descricao:
      'Temperatura: ${equipamento.temperatura.toStringAsFixed(1)} °C',
  serialNumber: equipamento.serialNumber,
  menu: AutomotiveMenu.comercial,
);
```

## 5.2 Adicionar um objeto `AutomotiveCardData`

```dart
final card = AutomotiveCardData(
  id: 'TK-I-0001',
  titulo: 'Câmara de Matéria-Prima',
  descricao: 'Temperatura: 3 °C',
  serialNumber: 'TK-I-0001',
  menu: AutomotiveMenu.industrial,
);

await AutomotiveManager.instance
    .adicionarCardSelecionado(card);
```

Esse método é indicado quando o aplicativo já trabalha com objetos `AutomotiveCardData`.

## Comportamento em caso de duplicidade

Caso já exista um card com o mesmo `id` no mesmo menu, ele será substituído pelos novos dados.

```dart
await AutomotiveManager.instance.adicionarCard(
  id: 'TK-C-0001',
  titulo: 'Câmara Fria Atualizada',
  descricao: 'Temperatura: 3.8 °C',
  menu: AutomotiveMenu.comercial,
);
```

O card anterior de ID `TK-C-0001` será atualizado.

---

# 6. Adicionar ou remover com a mesma função

A função `alternarCard` adiciona ou remove o card automaticamente.

```dart
final card = AutomotiveCardData(
  id: equipamento.serialNumber,
  titulo: equipamento.nome,
  descricao:
      'Temperatura: ${equipamento.temperatura} °C',
  serialNumber: equipamento.serialNumber,
  menu: AutomotiveMenu.comercial,
);

await AutomotiveManager.instance.alternarCard(card);
```

Comportamento:

* Se o card ainda não estiver no menu, ele será adicionado.
* Se o card já estiver no menu, ele será removido.

Essa função é indicada para:

```dart
Switch
Checkbox
ListTile
IconButton
onTap
```

Exemplo com `Switch`:

```dart
Switch(
  value: AutomotiveManager.instance.cardEstaAdicionado(
    id: equipamento.serialNumber,
    menu: AutomotiveMenu.comercial,
  ),
  onChanged: (_) async {
    await AutomotiveManager.instance.alternarCard(
      AutomotiveCardData(
        id: equipamento.serialNumber,
        titulo: equipamento.nome,
        descricao:
            'Temperatura: ${equipamento.temperatura} °C',
        serialNumber: equipamento.serialNumber,
        menu: AutomotiveMenu.comercial,
      ),
    );
  },
);
```

---

# 7. Verificar se um card está adicionado

```dart
final adicionado =
    AutomotiveManager.instance.cardEstaAdicionado(
  id: 'TK-C-0001',
  menu: AutomotiveMenu.comercial,
);
```

Resultado:

```dart
true
```

ou:

```dart
false
```

Exemplo de uso:

```dart
if (AutomotiveManager.instance.cardEstaAdicionado(
  id: equipamento.serialNumber,
  menu: AutomotiveMenu.comercial,
)) {
  debugPrint('O equipamento está no veículo.');
}
```

---

# 8. Remover um card

Para remover um card, informe o `id` e o menu.

```dart
await AutomotiveManager.instance.removerCard(
  id: 'TK-C-0001',
  menu: AutomotiveMenu.comercial,
);
```

Exemplo usando um equipamento:

```dart
await AutomotiveManager.instance.removerCard(
  id: equipamento.serialNumber,
  menu: equipamento.menu,
);
```

Caso o card não exista, nenhuma alteração será realizada.

---

# 9. Remover um card de todos os menus

Quando não se sabe em qual menu o card está:

```dart
await AutomotiveManager.instance
    .removerCardDeTodosOsMenus(
  'TK-C-0001',
);
```

Essa função procura o `id` nos menus:

```text
Residencial
Comercial
Industrial
```

Caso seja encontrado, será removido.

---

# 10. Remover todos os cards de um menu

Para limpar somente um menu:

```dart
await AutomotiveManager.instance.removerCardsDoMenu(
  AutomotiveMenu.comercial,
);
```

Exemplos:

```dart
await AutomotiveManager.instance.removerCardsDoMenu(
  AutomotiveMenu.residencial,
);
```

```dart
await AutomotiveManager.instance.removerCardsDoMenu(
  AutomotiveMenu.industrial,
);
```

Os outros menus permanecerão inalterados.

---

# 11. Remover todos os cards

Para limpar completamente o CarPlay e o Android Auto:

```dart
await AutomotiveManager.instance
    .removerTodosOsCards();
```

Isso limpa todos os menus.

---

# 12. Atualizar um card

A atualização normalmente será usada quando chegar uma nova informação por MQTT ou HTTP.

Para atualizar, informe:

* ID do equipamento.
* Menu.
* Campo que será alterado.

```dart
await AutomotiveManager.instance.atualizarCard(
  id: 'TK-C-0001',
  menu: AutomotiveMenu.comercial,
  descricao: 'Temperatura: 3.7 °C',
);
```

## Atualizar apenas o título

```dart
await AutomotiveManager.instance.atualizarCard(
  id: 'TK-C-0001',
  menu: AutomotiveMenu.comercial,
  titulo: 'Câmara Fria Principal',
);
```

## Atualizar apenas a descrição

```dart
await AutomotiveManager.instance.atualizarCard(
  id: 'TK-C-0001',
  menu: AutomotiveMenu.comercial,
  descricao: 'Temperatura: 4.2 °C',
);
```

## Atualizar vários campos

```dart
await AutomotiveManager.instance.atualizarCard(
  id: 'TK-C-0001',
  menu: AutomotiveMenu.comercial,
  titulo: 'Câmara Fria 01',
  descricao: '4.2 °C • 70% • Online',
  serialNumber: 'TK-C-0001',
);
```

A função atualiza somente os parâmetros informados.

---

# 13. Atualizar um card sem saber o menu

Quando a mensagem MQTT contém somente o número de série, use:

```dart
await AutomotiveManager.instance
    .atualizarCardEmQualquerMenu(
  id: 'TK-C-0001',
  descricao: 'Temperatura: 3.9 °C',
);
```

O gerenciador procurará o card em todos os menus.

Exemplo MQTT:

```dart
Future<void> processarTemperaturaMqtt({
  required String serialNumber,
  required double temperatura,
}) async {
  await AutomotiveManager.instance
      .atualizarCardEmQualquerMenu(
    id: serialNumber,
    descricao:
        'Temperatura: ${temperatura.toStringAsFixed(1)} °C',
  );
}
```

Essa opção é recomendada quando o serviço MQTT não conhece a categoria do equipamento.

---

# 14. Atualizar via MQTT

Exemplo de mensagem recebida:

```json
{
  "serial_number": "TK-C-0001",
  "temperatura": 4.2,
  "umidade": 68,
  "online": true
}
```

Processamento:

```dart
Future<void> processarMensagemMqtt(
  Map<String, dynamic> dados,
) async {
  final serialNumber =
      dados['serial_number'] as String?;

  final temperatura =
      (dados['temperatura'] as num?)?.toDouble();

  final umidade =
      (dados['umidade'] as num?)?.toDouble();

  final online = dados['online'] == true;

  if (serialNumber == null ||
      temperatura == null) {
    return;
  }

  final descricao =
      '${temperatura.toStringAsFixed(1)} °C'
      '${umidade != null ? ' • ${umidade.toStringAsFixed(0)}%' : ''}'
      ' • ${online ? 'Online' : 'Offline'}';

  await AutomotiveManager.instance
      .atualizarCardEmQualquerMenu(
    id: serialNumber,
    descricao: descricao,
  );
}
```

O card só será atualizado se estiver selecionado pelo usuário.

Equipamentos não selecionados não serão adicionados automaticamente.

---

# 15. Atualizar via HTTP

Exemplo:

```dart
Future<void> atualizarEquipamentoViaHttp() async {
  final equipamento =
      await equipamentoService.buscarEquipamento(
    'TK-C-0001',
  );

  await AutomotiveManager.instance
      .atualizarCardEmQualquerMenu(
    id: equipamento.serialNumber,
    titulo: equipamento.nome,
    descricao:
        '${equipamento.temperatura.toStringAsFixed(1)} °C'
        ' • ${equipamento.online ? 'Online' : 'Offline'}',
    serialNumber: equipamento.serialNumber,
  );
}
```

O HTTP pode ser utilizado para:

* Carregar os dados iniciais.
* Recuperar o estado após uma desconexão.
* Buscar informações completas do equipamento.
* Corrigir informações perdidas durante uma interrupção do MQTT.

---

# 16. Mover um card entre menus

Para mover um equipamento de um menu para outro:

```dart
await AutomotiveManager.instance.moverCard(
  id: 'TK-C-0001',
  menuAtual: AutomotiveMenu.comercial,
  novoMenu: AutomotiveMenu.industrial,
);
```

Outro exemplo:

```dart
await AutomotiveManager.instance.moverCard(
  id: equipamento.serialNumber,
  menuAtual: AutomotiveMenu.residencial,
  novoMenu: AutomotiveMenu.comercial,
);
```

A função:

1. Remove o card do menu atual.
2. Atualiza a propriedade `menu`.
3. Adiciona o card ao novo menu.
4. Atualiza o CarPlay ou Android Auto.

---

# 17. Consultar cards de um menu

```dart
final cardsComerciais =
    AutomotiveManager.instance.cardsDoMenu(
  AutomotiveMenu.comercial,
);
```

Percorrendo a lista:

```dart
for (final card in cardsComerciais) {
  debugPrint(card.titulo);
}
```

Outros exemplos:

```dart
final cardsResidenciais =
    AutomotiveManager.instance.cardsDoMenu(
  AutomotiveMenu.residencial,
);
```

```dart
final cardsIndustriais =
    AutomotiveManager.instance.cardsDoMenu(
  AutomotiveMenu.industrial,
);
```

A lista retornada não pode ser modificada diretamente.

---

# 18. Consultar todos os cards

```dart
final todosOsCards =
    AutomotiveManager.instance.todosOsCards;
```

Exemplo:

```dart
for (final card in todosOsCards) {
  debugPrint(
    '${card.titulo} - ${card.menu.titulo}',
  );
}
```

---

# 19. Consultar quantidade de cards

## Quantidade total

```dart
final quantidade =
    AutomotiveManager.instance.quantidadeTotalCards;
```

## Quantidade em um menu

```dart
final quantidadeComercial =
    AutomotiveManager.instance.quantidadeCardsNoMenu(
  AutomotiveMenu.comercial,
);
```

## Verificar se existe algum card

```dart
final possuiCards =
    AutomotiveManager.instance.possuiCards;
```

Exemplo:

```dart
if (!AutomotiveManager.instance.possuiCards) {
  debugPrint('Nenhum card está selecionado.');
}
```

---

# 20. Encontrar um card específico

```dart
final card =
    AutomotiveManager.instance.encontrarCard(
  id: 'TK-C-0001',
  menu: AutomotiveMenu.comercial,
);
```

É necessário verificar se o resultado é nulo:

```dart
if (card != null) {
  debugPrint(card.titulo);
}
```

---

# 21. Consultar o último clique

```dart
final ultimoClique =
    AutomotiveManager.instance.ultimoClique;
```

Uso:

```dart
if (ultimoClique != null) {
  debugPrint(ultimoClique.card.titulo);
  debugPrint(ultimoClique.plataforma);
  debugPrint(
    ultimoClique.card.menu.titulo,
  );
}
```

---

# 22. Consultar conexão

## Verificar se está conectado

```dart
final conectado =
    AutomotiveManager.instance.conectado;
```

## Consultar status textual

```dart
final status =
    AutomotiveManager.instance.statusConexao;
```

Possíveis resultados:

```text
CarPlay conectado
CarPlay desconectado
CarPlay em segundo plano
Android Auto conectado
Android Auto desconectado
Android Auto em segundo plano
```

## Consultar plataforma

```dart
final plataforma =
    AutomotiveManager.instance.plataforma;
```

Possíveis valores:

```text
CarPlay
Android Auto
Sistema automotivo
```

---

# 23. Escutar mudanças no gerenciador

Como o `AutomotiveManager` estende `ChangeNotifier`, uma tela pode escutar alterações.

```dart
@override
void initState() {
  super.initState();

  AutomotiveManager.instance.addListener(
    _onAutomotiveManagerChanged,
  );
}

void _onAutomotiveManagerChanged() {
  if (!mounted) {
    return;
  }

  setState(() {});
}
```

No `dispose`:

```dart
@override
void dispose() {
  AutomotiveManager.instance.removeListener(
    _onAutomotiveManagerChanged,
  );

  super.dispose();
}
```

Também é possível usar `AnimatedBuilder`:

```dart
AnimatedBuilder(
  animation: AutomotiveManager.instance,
  builder: (context, child) {
    return Text(
      '${AutomotiveManager.instance.quantidadeTotalCards} cards',
    );
  },
);
```

---

# 24. Fluxo recomendado para MQTT

```text
Mensagem MQTT recebida
        ↓
Decodificar JSON
        ↓
Atualizar estado principal do equipamento
        ↓
Chamar atualizarCardEmQualquerMenu()
        ↓
Se o card estiver selecionado, atualizar o veículo
        ↓
Se não estiver selecionado, não fazer nada no veículo
```

Exemplo:

```dart
Future<void> onTemperaturaRecebida({
  required String serialNumber,
  required double temperatura,
}) async {
  atualizarEquipamentoNoAplicativo(
    serialNumber: serialNumber,
    temperatura: temperatura,
  );

  await AutomotiveManager.instance
      .atualizarCardEmQualquerMenu(
    id: serialNumber,
    descricao:
        'Temperatura: ${temperatura.toStringAsFixed(1)} °C',
  );
}
```

---

# 25. Fluxo recomendado para HTTP

```text
Aplicativo iniciado
        ↓
Buscar equipamentos pela API
        ↓
Atualizar estado principal do Flutter
        ↓
Atualizar cards já selecionados
        ↓
CarPlay ou Android Auto recebe os dados mais recentes
```

Exemplo:

```dart
Future<void> sincronizarEquipamentos() async {
  final equipamentos =
      await equipamentoService.listar();

  for (final equipamento in equipamentos) {
    await AutomotiveManager.instance
        .atualizarCardEmQualquerMenu(
      id: equipamento.serialNumber,
      titulo: equipamento.nome,
      descricao:
          '${equipamento.temperatura.toStringAsFixed(1)} °C'
          ' • ${equipamento.online ? 'Online' : 'Offline'}',
    );
  }
}
```

---

# 26. Exemplo completo de inclusão

```dart
Future<void> adicionarAoCarPlay(
  Equipamento equipamento,
) async {
  await AutomotiveManager.instance.adicionarCard(
    id: equipamento.serialNumber,
    titulo: equipamento.nome,
    descricao:
        '${equipamento.temperatura.toStringAsFixed(1)} °C'
        ' • ${equipamento.online ? 'Online' : 'Offline'}',
    serialNumber: equipamento.serialNumber,
    menu: AutomotiveMenu.comercial,
  );
}
```

---

# 27. Exemplo completo de atualização

```dart
Future<void> atualizarNoCarPlay(
  Equipamento equipamento,
) async {
  await AutomotiveManager.instance
      .atualizarCardEmQualquerMenu(
    id: equipamento.serialNumber,
    titulo: equipamento.nome,
    descricao:
        '${equipamento.temperatura.toStringAsFixed(1)} °C'
        ' • ${equipamento.umidade.toStringAsFixed(0)}%'
        ' • ${equipamento.online ? 'Online' : 'Offline'}',
  );
}
```

---

# 28. Exemplo completo de remoção

```dart
Future<void> removerDoCarPlay(
  Equipamento equipamento,
) async {
  await AutomotiveManager.instance.removerCard(
    id: equipamento.serialNumber,
    menu: equipamento.menuAutomotivo,
  );
}
```

Quando o menu não estiver disponível:

```dart
Future<void> removerDoCarPlay(
  Equipamento equipamento,
) async {
  await AutomotiveManager.instance
      .removerCardDeTodosOsMenus(
    equipamento.serialNumber,
  );
}
```

---

# 29. Resumo das funções

## Inicialização

```dart
inicializar()
```

## Adicionar

```dart
adicionarCard()
adicionarCardSelecionado()
alternarCard()
```

## Atualizar

```dart
atualizarCard()
atualizarCardEmQualquerMenu()
```

## Remover

```dart
removerCard()
removerCardDeTodosOsMenus()
removerCardsDoMenu()
removerTodosOsCards()
```

## Mover

```dart
moverCard()
```

## Consultar

```dart
cardsDoMenu()
todosOsCards
cardEstaAdicionado()
encontrarCard()
quantidadeCardsNoMenu()
quantidadeTotalCards
possuiCards
ultimoClique
conectado
statusConexao
plataforma
```

## Encerrar

```dart
encerrar()
```

---

# 30. Observações importantes

O `id` deve permanecer igual em todas as operações.

Exemplo correto:

```dart
adicionarCard(
  id: 'TK-C-0001',
);
```

```dart
atualizarCard(
  id: 'TK-C-0001',
);
```

```dart
removerCard(
  id: 'TK-C-0001',
);
```

Evite utilizar nomes como identificador:

```dart
id: 'Câmara Fria'
```

Prefira o número de série:

```dart
id: equipamento.serialNumber
```

O card não é criado automaticamente ao receber uma mensagem MQTT. O usuário deve primeiro selecionar o equipamento.

Depois que o card estiver selecionado, as informações podem ser atualizadas por:

```dart
atualizarCard()
```

ou:

```dart
atualizarCardEmQualquerMenu()
```

O `AutomotiveManager` não deve realizar diretamente conexões MQTT ou chamadas HTTP. Ele deve receber os dados já processados pelos serviços responsáveis.

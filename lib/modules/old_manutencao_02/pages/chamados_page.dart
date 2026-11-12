import 'package:flutter/material.dart';
import '../../../colors/colors.dart';
import '../services/app_manutencao_acesso_service.dart';
import '../services/manutencao_deck_gerencial_service.dart';
import '../services/manutencao_prioridade.dart';

class ChamadosPage extends StatefulWidget {
  const ChamadosPage({super.key});
  @override
  State<ChamadosPage> createState() => _ChamadosPageState();
}
class _ChamadosPageState extends State<ChamadosPage> {
  final _service = ManutencaoDeckGerencialService();
  final _busca = TextEditingController();
  late Future<List<DeckChamadoGerencial>> _futuro;
  String _filtro = 'Todos';
  @override
  void initState() { super.initState(); _atualizar(); }
  void _atualizar() { _futuro = _carregar(); }
  Future<List<DeckChamadoGerencial>> _carregar() async {
    if (!(await AppManutencaoAcessoService().carregar()).chamados) throw StateError('Sem permissão para Chamados.');
    return _service.listar();
  }
  @override
  void dispose() { _busca.dispose(); _service.dispose(); super.dispose(); }
  String _status(DeckChamadoGerencial c) {
    if (c.concluido) return 'Concluída';
    if (c.vencimento == null) return 'Sem data';
    final h = DateTime.now();
    final dias = DateTime(c.vencimento!.year,c.vencimento!.month,c.vencimento!.day)
      .difference(DateTime(h.year,h.month,h.day)).inDays;
    if (dias < 0) return 'Atrasada';
    if (dias == 0) return 'Hoje';
    if (dias == 1) return 'Amanhã';
    return 'Próximos dias';
  }
  Color _cor(String s) => switch(s) {
    'Atrasada' => const Color(0xFFC62828),
    'Amanhã' => BillhardColors.terraCota,
    'Próximos dias' => const Color(0xFF1565C0),
    'Concluída' => const Color(0xFF15803D),
    _ => BillhardColors.verdePrincipal,
  };
  String _data(DateTime? d) => d == null ? 'Sem data' :
    '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  Widget _resumo(String nome, int total, Color cor, IconData icone) =>
    Container(width: 135, padding: const EdgeInsets.all(13), decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: Border(bottom: BorderSide(color: cor, width: 4))),
      child: Column(children: [Icon(icone,color:cor,size:27),const SizedBox(height: 5),
        Text('$total',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:BillhardColors.verdePrincipal)),
        Text(nome,style:const TextStyle(fontSize:12),textAlign:TextAlign.center)]));
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BillhardColors.bege,
    appBar: AppBar(title: const Text('Manutenção',style:TextStyle(fontWeight:FontWeight.w800)),
      backgroundColor:BillhardColors.verdePrincipal,foregroundColor:Colors.white,
      actions:[IconButton(tooltip:'Atualizar',onPressed:()=>setState(_atualizar),icon:const Icon(Icons.refresh))]),
    body: FutureBuilder<List<DeckChamadoGerencial>>(future:_futuro,builder:(context,snapshot){
      if (!snapshot.hasData) return Center(child:snapshot.hasError ? Padding(
        padding:const EdgeInsets.all(20),child:Text('${snapshot.error}',textAlign:TextAlign.center))
        :const CircularProgressIndicator(color:BillhardColors.verdePrincipal));
      final todos=snapshot.data!;
      final itens=todos.where((c)=>(_filtro=='Todos'||_status(c)==_filtro)&&
        '${c.titulo} ${c.tecnico} ${c.lista}'.toLowerCase().contains(_busca.text.toLowerCase())).toList()
        ..sort((a,b)=>(a.vencimento??DateTime(9999)).compareTo(b.vencimento??DateTime(9999)));
      return RefreshIndicator(onRefresh:()async{setState(_atualizar);await _futuro;},
        child:ListView(padding:const EdgeInsets.fromLTRB(16,20,16,24),children:[
          const Text('Chamados',style:TextStyle(fontSize:27,fontWeight:FontWeight.w900,color:BillhardColors.verdePrincipal)),
          const Text('Gerencie e acompanhe as manutenções da planta',style:TextStyle(color:BillhardColors.verdePrincipal)),
          const SizedBox(height:20),
          SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
            _resumo('Atrasadas',todos.where((c)=>_status(c)=='Atrasada').length,_cor('Atrasada'),Icons.schedule),
            const SizedBox(width:9),_resumo('Em dia',todos.where((c)=>_status(c)=='Hoje').length,const Color(0xFF15803D),Icons.check_circle_outline),
            const SizedBox(width:9),_resumo('Para amanhã',todos.where((c)=>_status(c)=='Amanhã').length,_cor('Amanhã'),Icons.event),
            const SizedBox(width:9),_resumo('Próximos dias',todos.where((c)=>_status(c)=='Próximos dias').length,_cor('Próximos dias'),Icons.date_range),
          ])),
          const SizedBox(height:20),
          TextField(controller:_busca,onChanged:(_)=>setState((){}),
            decoration:const InputDecoration(hintText:'Buscar chamado, equipamento ou técnico...',prefixIcon:Icon(Icons.search,color:BillhardColors.verdePrincipal))),
          const SizedBox(height:12),
          SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
            for(final f in ['Todos','Atrasada','Hoje','Amanhã','Próximos dias','Sem data','Concluída'])
              Padding(padding:const EdgeInsets.only(right:7),child:ChoiceChip(label:Text(f),selected:_filtro==f,
                selectedColor:BillhardColors.verdeSecundario,
                labelStyle:const TextStyle(color:BillhardColors.verdePrincipal),
                onSelected:(_)=>setState(()=>_filtro=f))),
          ])),
          const SizedBox(height:12),
          if(itens.isEmpty) const Padding(padding:EdgeInsets.all(30),child:Center(child:Text('Nenhum chamado encontrado.'))),
          for(final c in itens) Builder(builder:(context){
            final status=_status(c),cor=_cor(status);
            return Container(margin:const EdgeInsets.only(bottom:12),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),
                border:Border(left:BorderSide(color:cor,width:5))),
              child:Padding(padding:const EdgeInsets.all(15),child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[Icon(Icons.build_circle_outlined,color:BillhardColors.verdePrincipal,size:31),
                    const SizedBox(width:10),Expanded(child:Text(c.titulo,style:const TextStyle(
                      fontWeight:FontWeight.w800,fontSize:16,color:BillhardColors.verdePrincipal)))]),
                  const SizedBox(height:9),
                  Wrap(spacing:8,runSpacing:6,crossAxisAlignment:WrapCrossAlignment.center,children:[
                    Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                      decoration:BoxDecoration(color:cor.withValues(alpha:.12),borderRadius:BorderRadius.circular(20)),
                      child:Text(status,style:TextStyle(color:cor,fontWeight:FontWeight.w800))),
                    Icon(Icons.event_outlined,size:17,color:cor),
                    Text('Venc.: ${_data(c.vencimento)}',style:TextStyle(color:cor)),
                  ]),
                  const SizedBox(height:8),
                  Row(children:[const Icon(Icons.precision_manufacturing_outlined,size:18,color:BillhardColors.verdePrincipal),
                    const SizedBox(width:7),Expanded(child:Text(c.lista))]),
                  const SizedBox(height:5),
                  Row(children:[const Icon(Icons.person,size:18,color:BillhardColors.verdePrincipal),
                    const SizedBox(width:7),Expanded(child:Text(c.tecnico))]),
                  if(c.etiquetas.isNotEmpty) Padding(padding:const EdgeInsets.only(top:9),
                    child:Wrap(spacing:6,runSpacing:5,children:[for(final e in c.etiquetas)
                      Chip(label:Text(e.nome,style:const TextStyle(fontSize:12)),
                        backgroundColor:ManutencaoPrioridade.cor(e.cor).withValues(alpha:.18),
                        side:BorderSide(color:ManutencaoPrioridade.cor(e.cor).withValues(alpha:.45)))])),
                ])));
          }),
        ]));
    }),
  );
}

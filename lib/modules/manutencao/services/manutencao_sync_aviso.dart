import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ManutencaoSyncAviso extends StatefulWidget {
  const ManutencaoSyncAviso({
    super.key,
    required this.aviso,
    required this.pendentes,
  });

  final String? aviso;
  final int pendentes;

  @override
  State<ManutencaoSyncAviso> createState() => _ManutencaoSyncAvisoState();
}

class _ManutencaoSyncAvisoState extends State<ManutencaoSyncAviso> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final aviso = widget.aviso?.trim() ?? '';
    final temAviso = aviso.isNotEmpty;

    if (!temAviso && widget.pendentes == 0) {
      return const SizedBox.shrink();
    }

    final cores = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cores.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cores.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.pendentes > 0
                    ? Icons.cloud_upload_outlined
                    : Icons.info_outline,
                color: cores.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.pendentes > 0
                      ? '${widget.pendentes} envio(s) pendente(s)'
                      : 'Aviso da última sincronização',
                ),
              ),
              if (temAviso)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _expandido = !_expandido;
                    });
                  },
                  child: Text(_expandido ? 'Ocultar' : 'Ver aviso'),
                ),
            ],
          ),
          if (_expandido && temAviso) ...[
            const Divider(),
            SelectableText(aviso, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: aviso));

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Detalhes copiados.')),
                  );
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copiar erro'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medidor_humedad/models/access_request.dart';
import 'package:medidor_humedad/models/field.dart';
import 'package:medidor_humedad/services/cloud_service.dart';
import 'package:medidor_humedad/widgets/smart_dashboard.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Pantalla del dueño del campo para invitar a otras personas a ver la app.
/// Genera un código/QR, muestra las solicitudes de acceso en tiempo real y
/// permite aprobar, rechazar o bloquear a cada invitado.
class AccessShareScreen extends StatefulWidget {
  final String uid;
  const AccessShareScreen({super.key, required this.uid});

  @override
  State<AccessShareScreen> createState() => _AccessShareScreenState();
}

class _AccessShareScreenState extends State<AccessShareScreen> {
  List<Field> _fields = [];
  String? _selectedFieldId;
  bool _loading = true;
  bool _creating = false;
  String? _error;
  late final Stream<List<AccessRequest>> _requests;

  @override
  void initState() {
    super.initState();
    _requests = CloudService.instance.streamAccessRequests(widget.uid);
    _loadFields();
  }

  Future<void> _loadFields() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fields = await CloudService.instance.myFields(widget.uid);
      if (!mounted) return;
      setState(() {
        _fields = fields;
        if (_selectedFieldId == null && fields.isNotEmpty) {
          _selectedFieldId = fields.first.id;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los campos: $e';
        _loading = false;
      });
    }
  }

  String _inviteUrl(String token) =>
      'https://medidor-de-humedad.web.app/invitacion?token=$token';

  Future<void> _createInvite() async {
    final fieldId = _selectedFieldId;
    if (fieldId == null) return;
    setState(() => _creating = true);
    try {
      final token =
          await CloudService.instance.createInvite(widget.uid, fieldId);
      if (!mounted) return;
      await _showInviteSheet(token);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la invitación: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _showInviteSheet(String token) async {
    final url = _inviteUrl(token);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Invita a otra persona',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: kText,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Escanea el código o comparte el enlace. La persona se registra '
              'con su correo y clave, y te pedirá acceso.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kText2),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 190,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Código: $token',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kGreen,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: token));
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Código copiado')),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kBlue,
                      side: const BorderSide(color: kBorder),
                    ),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copiar código',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Share.share(
                        'Te invito a ver la humedad y el riego de mi campo en '
                        'tiempo real.\n'
                        'Descarga la app y entra con el código: $token\n$url',
                        subject: 'Invitación a Medidor de Humedad',
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kGreen,
                      side: const BorderSide(color: kBorder),
                    ),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('WhatsApp · Gmail · otros',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(AccessRequest req) async {
    try {
      await CloudService.instance.approveAccess(req);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Acceso otorgado a ${req.email}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo aprobar: $e')),
      );
    }
  }

  Future<void> _reject(AccessRequest req) async {
    try {
      await CloudService.instance.rejectAccess(req);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solicitud rechazada de ${req.email}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo rechazar: $e')),
      );
    }
  }

  Future<void> _revoke(AccessRequest req) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Bloquear acceso',
            style: TextStyle(color: kText)),
        content: Text(
          '¿Bloquear a ${req.email}? Dejará de ver tus datos y no podrá '
          'ingresar de nuevo.',
          style: const TextStyle(color: kText2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: kText2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Bloquear', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CloudService.instance.revokeAccess(req);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Acceso bloqueado para ${req.email}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo bloquear: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDbg,
      appBar: AppBar(
        backgroundColor: kCard,
        foregroundColor: kText,
        title: const Text('Compartir acceso'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!, style: const TextStyle(color: kRed)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _loadFields,
                        style: FilledButton.styleFrom(backgroundColor: kGreen),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _howItWorks(),
                    const SizedBox(height: 20),
                    if (_fields.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Aún no tienes campos configurados para compartir.',
                          style: TextStyle(color: kText2),
                        ),
                      )
                    else ...[
                      if (_fields.length > 1) ...[
                        Text(
                          'Campo a compartir',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kText2),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedFieldId,
                          dropdownColor: kCard,
                          style: const TextStyle(color: kText),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: kCard,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: kBorder),
                            ),
                          ),
                          items: [
                            for (final f in _fields)
                              DropdownMenuItem(
                                  value: f.id, child: Text(f.name)),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedFieldId = v),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton.icon(
                        onPressed: _creating ? null : _createInvite,
                        style: FilledButton.styleFrom(backgroundColor: kGreen),
                        icon: _creating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.qr_code_2),
                        label: Text(_fields.length > 1
                            ? 'Crear invitación de este campo'
                            : 'Crear invitación (código QR)'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Solicitudes de acceso',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: kText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<AccessRequest>>(
                      stream: _requests,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No se pudieron cargar las solicitudes: '
                              '${snapshot.error}',
                              style: const TextStyle(color: kOrange),
                            ),
                          );
                        }
                        final list = snapshot.data ?? const [];
                        if (list.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Aún no hay solicitudes de acceso.',
                              style: TextStyle(color: kText2),
                            ),
                          );
                        }
                        return Column(
                          children: [for (final r in list) _requestCard(r)],
                        );
                      },
                    ),
                  ],
                ),
    );
  }

  Widget _howItWorks() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Cómo funciona',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: kGreen,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '1. Comparte el código QR por WhatsApp, correo u otra app.\n'
            '2. La persona instala la app y se registra con su correo y clave, '
            'ingresando el código.\n'
            '3. Te llegará aquí su solicitud y podrás aprobarla (solo una vez '
            'por correo; después entrará directo).\n'
            '4. Verá tus datos en tiempo real, en modo solo lectura. Puedes '
            'bloquearla cuando quieras.',
            style: TextStyle(fontSize: 12, color: kText2, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(AccessRequest r) {
    final Color color;
    final String label;
    switch (r.status) {
      case 'approved':
        color = kGreen;
        label = 'Aprobado';
        break;
      case 'rejected':
        color = kOrange;
        label = 'Rechazado';
        break;
      case 'revoked':
        color = kRed;
        label = 'Bloqueado';
        break;
      default:
        color = kBlue;
        label = 'Pendiente';
    }
    final when = r.requestedAt;
    final whenText = when == null
        ? ''
        : '${when.day.toString().padLeft(2, '0')}/'
            '${when.month.toString().padLeft(2, '0')} '
            '${when.hour.toString().padLeft(2, '0')}:'
            '${when.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.email,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kText,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (whenText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(whenText, style: const TextStyle(fontSize: 12, color: kText3)),
          ],
          if (r.isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _approve(r),
                    style: FilledButton.styleFrom(backgroundColor: kGreen),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Aprobar', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reject(r),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kRed,
                      side: const BorderSide(color: kBorder),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Rechazar', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ] else if (r.isApproved) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _revoke(r),
                style: TextButton.styleFrom(foregroundColor: kRed),
                icon: const Icon(Icons.block, size: 18),
                label: const Text('Bloquear acceso'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:medidor_humedad/models/crop.dart';
import 'package:medidor_humedad/models/field.dart';
import 'package:medidor_humedad/services/cloud_service.dart';
import 'package:medidor_humedad/widgets/smart_dashboard.dart';

import 'access_share_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String uid;
  const SettingsScreen({super.key, required this.uid});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Crop> _crops = [];
  List<Field> _fields = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final crops = await CloudService.instance.myCrops(widget.uid);
      final fields = await CloudService.instance.myFields(widget.uid);
      if (!mounted) return;
      setState(() {
        _crops = crops..sort((a, b) => a.name.compareTo(b.name));
        _fields = fields;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los datos: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openCropForm({Crop? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CropFormScreen(uid: widget.uid, existing: existing),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteCrop(Crop crop) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Eliminar cultivo',
            style: TextStyle(color: kText)),
        content: Text(
          '¿Eliminar "${crop.name}"? Los sectores que usen este cultivo '
          'quedarán sin umbral de riego.',
          style: const TextStyle(color: kText2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: kText2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CloudService.instance.deleteCrop(crop.id);
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }

  Future<void> _openFieldForm(Field field) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _FieldFormScreen(uid: widget.uid, field: field),
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDbg,
      appBar: AppBar(
        backgroundColor: kCard,
        foregroundColor: kText,
        title: const Text('Configuración'),
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
                        onPressed: _load,
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
                    _sectionTitle('Compartir acceso',
                        Icons.people_outline),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Invita a otra persona para que vea tu campo en tiempo '
                        'real (solo lectura). Genera un código QR y aprueba o '
                        'bloquea los accesos.',
                        style: TextStyle(color: kText2, fontSize: 12),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AccessShareScreen(uid: widget.uid),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(backgroundColor: kGreen),
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Compartir acceso'),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Cultivos y umbrales de riego',
                        Icons.eco_outlined),
                    if (_crops.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Aún no tienes cultivos.',
                            style: TextStyle(color: kText2)),
                      )
                    else
                      for (final c in _crops) _cropCard(c),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => _openCropForm(),
                      style: FilledButton.styleFrom(backgroundColor: kGreen),
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo cultivo'),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Campo y equipamiento',
                        Icons.agriculture_outlined),
                    if (_fields.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Aún no tienes campos.',
                            style: TextStyle(color: kText2)),
                      )
                    else
                      for (final f in _fields) _fieldCard(f),
                  ],
                ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kGreen),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: kText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _cropCard(Crop c) {
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
                  c.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: kText,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _openCropForm(existing: c),
                icon: const Icon(Icons.edit_outlined, color: kBlue, size: 20),
                tooltip: 'Editar',
              ),
              IconButton(
                onPressed: () => _deleteCrop(c),
                icon: const Icon(Icons.delete_outline, color: kRed, size: 20),
                tooltip: 'Eliminar',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip('Riego bajo ${c.irrigateBelow.toStringAsFixed(0)}%', kOrange),
              _chip(
                  'Humedad ${c.minHumidity.toStringAsFixed(0)}–${c.maxHumidity.toStringAsFixed(0)}%',
                  kGreen),
              _chip(
                  'Temp ${c.minTemp.toStringAsFixed(0)}–${c.maxTemp.toStringAsFixed(0)}°C',
                  kBlue),
              if (c.kc != null) _chip('Kc ${c.kc!.toStringAsFixed(2)}', kText2),
              if (c.etpMmDay != null)
                _chip('ETP ${c.etpMmDay!.toStringAsFixed(1)} mm/d', kText2),
              if (c.efficiencyPct != null)
                _chip('Efic. ${c.efficiencyPct!.toStringAsFixed(0)}%', kText2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldCard(Field f) {
    final info = [
      if (f.pumpModel != null && f.pumpModel!.isNotEmpty) 'Bomba ${f.pumpModel}',
      if (f.pumpHp != null && f.pumpHp!.isNotEmpty) '${f.pumpHp}',
      if (f.filterType != null && f.filterType!.isNotEmpty)
        'Filtro ${f.filterType}',
      if (f.filterInches != null && f.filterInches!.isNotEmpty)
        '${f.filterInches}',
      if (f.filterModel != null && f.filterModel!.isNotEmpty)
        '${f.filterModel}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: kText,
                  ),
                ),
                if (info.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(info,
                      style: const TextStyle(fontSize: 12, color: kText2)),
                ],
                if (f.lat != null && f.lon != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${f.lat!.toStringAsFixed(5)}, ${f.lon!.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 12, color: kText3),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => _openFieldForm(f),
            icon: const Icon(Icons.edit_outlined, color: kBlue, size: 20),
            tooltip: 'Editar',
          ),
        ],
      ),
    );
  }
}

class _CropFormScreen extends StatefulWidget {
  final String uid;
  final Crop? existing;
  const _CropFormScreen({required this.uid, this.existing});

  @override
  State<_CropFormScreen> createState() => _CropFormScreenState();
}

class _CropFormScreenState extends State<_CropFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _minHum;
  late final TextEditingController _maxHum;
  late final TextEditingController _irrigateBelow;
  late final TextEditingController _minTemp;
  late final TextEditingController _maxTemp;
  late final TextEditingController _kc;
  late final TextEditingController _etp;
  late final TextEditingController _etActual;
  late final TextEditingController _efficiency;
  late final TextEditingController _lamina;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _minHum = TextEditingController(
        text: c == null ? '30' : c.minHumidity.toStringAsFixed(0));
    _maxHum = TextEditingController(
        text: c == null ? '70' : c.maxHumidity.toStringAsFixed(0));
    _irrigateBelow = TextEditingController(
        text: c == null ? '35' : c.irrigateBelow.toStringAsFixed(0));
    _minTemp =
        TextEditingController(text: c == null ? '8' : c.minTemp.toStringAsFixed(0));
    _maxTemp =
        TextEditingController(text: c == null ? '32' : c.maxTemp.toStringAsFixed(0));
    _kc = TextEditingController(
        text: c?.kc?.toStringAsFixed(2) ?? (c == null ? '' : ''));
    _etp = TextEditingController(
        text: c?.etpMmDay?.toStringAsFixed(1) ?? '');
    _etActual = TextEditingController(
        text: c?.etActualMmDay?.toStringAsFixed(1) ?? '');
    _efficiency = TextEditingController(
        text: c?.efficiencyPct?.toStringAsFixed(0) ?? '');
    _lamina = TextEditingController(
        text: c?.laminaBrutaMmDay?.toStringAsFixed(1) ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _name, _minHum, _maxHum, _irrigateBelow, _minTemp, _maxTemp,
      _kc, _etp, _etActual, _efficiency, _lamina,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _requiredNum(TextEditingController c, String label) {
    if (c.text.trim().isEmpty) return 'Ingresa $label';
    if (double.tryParse(c.text.replaceAll(',', '.')) == null) {
      return '$label inválido';
    }
    return null;
  }

  String? _optionalNum(TextEditingController c, String label) {
    if (c.text.trim().isEmpty) return null;
    if (double.tryParse(c.text.replaceAll(',', '.')) == null) {
      return '$label inválido';
    }
    return null;
  }

  double _val(TextEditingController c, double fallback) {
    return double.tryParse(c.text.replaceAll(',', '.')) ?? fallback;
  }

  double? _optVal(TextEditingController c) {
    return c.text.trim().isEmpty ? null : double.tryParse(c.text.replaceAll(',', '.'));
  }

  Widget _field(TextEditingController c, String label,
      {String? hint, String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      style: const TextStyle(color: kText),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: kText2),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kGreen),
        ),
        filled: true,
        fillColor: kCard,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final minHum = _val(_minHum, 30);
    final maxHum = _val(_maxHum, 70);
    final irrigateBelow = _val(_irrigateBelow, 35);
    final minTemp = _val(_minTemp, 8);
    final maxTemp = _val(_maxTemp, 32);
    if (minHum >= maxHum) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La humedad mínima debe ser menor que la máxima')));
      return;
    }
    if (irrigateBelow <= minHum || irrigateBelow >= maxHum) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'El umbral de riego debe estar entre la humedad mínima y máxima')));
      return;
    }
    if (minTemp >= maxTemp) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La temperatura mínima debe ser menor que la máxima')));
      return;
    }
    setState(() => _saving = true);
    try {
      final crop = Crop(
        id: widget.existing?.id ?? '',
        name: _name.text.trim(),
        owner: widget.uid,
        minHumidity: minHum,
        maxHumidity: maxHum,
        minTemp: minTemp,
        maxTemp: maxTemp,
        irrigateBelow: irrigateBelow,
        kc: _optVal(_kc),
        etpMmDay: _optVal(_etp),
        etActualMmDay: _optVal(_etActual),
        efficiencyPct: _optVal(_efficiency),
        laminaBrutaMmDay: _optVal(_lamina),
      );
      if (widget.existing == null) {
        await CloudService.instance.createCrop(widget.uid, crop);
      } else {
        await CloudService.instance.updateCrop(widget.existing!.id, crop);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Scaffold(
      backgroundColor: kDbg,
      appBar: AppBar(
        backgroundColor: kCard,
        foregroundColor: kText,
        title: Text(isNew ? 'Nuevo cultivo' : 'Editar cultivo'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Guardar',
                style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_name, 'Nombre del cultivo', validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingresa el nombre';
              return null;
            }),
            const SizedBox(height: 12),
            _field(_minHum, 'Humedad mínima (%)',
                validator: (v) => _requiredNum(_minHum, 'la humedad mínima')),
            const SizedBox(height: 12),
            _field(_maxHum, 'Humedad máxima (%)',
                validator: (v) => _requiredNum(_maxHum, 'la humedad máxima')),
            const SizedBox(height: 12),
            _field(
              _irrigateBelow,
              'Umbral de riego (%)',
              hint: 'Alerta cuando la humedad baja de este valor',
              validator: (v) => _requiredNum(_irrigateBelow, 'el umbral de riego'),
            ),
            const SizedBox(height: 12),
            _field(_minTemp, 'Temp. mínima (°C)',
                validator: (v) => _requiredNum(_minTemp, 'la temp. mínima')),
            const SizedBox(height: 12),
            _field(_maxTemp, 'Temp. máxima (°C)',
                validator: (v) => _requiredNum(_maxTemp, 'la temp. máxima')),
            const SizedBox(height: 12),
            _field(_kc, 'Coeficiente Kc',
                validator: (v) => _optionalNum(_kc, 'Kc')),
            const SizedBox(height: 12),
            _field(_etp, 'ETP (mm/día)',
                validator: (v) => _optionalNum(_etp, 'ETP')),
            const SizedBox(height: 12),
            _field(_etActual, 'ET actual (mm/día)',
                validator: (v) => _optionalNum(_etActual, 'ET actual')),
            const SizedBox(height: 12),
            _field(_efficiency, 'Eficiencia (%)',
                validator: (v) => _optionalNum(_efficiency, 'la eficiencia')),
            const SizedBox(height: 12),
            _field(_lamina, 'Lámina bruta (mm/día)',
                validator: (v) => _optionalNum(_lamina, 'la lámina')),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: kGreen),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(isNew ? 'Crear cultivo' : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldFormScreen extends StatefulWidget {
  final String uid;
  final Field field;
  const _FieldFormScreen({required this.uid, required this.field});

  @override
  State<_FieldFormScreen> createState() => _FieldFormScreenState();
}

class _FieldFormScreenState extends State<_FieldFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _lat;
  late final TextEditingController _lon;
  late final TextEditingController _pumpModel;
  late final TextEditingController _pumpHp;
  late final TextEditingController _filterType;
  late final TextEditingController _filterInches;
  late final TextEditingController _filterModel;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.field;
    _name = TextEditingController(text: f.name);
    _lat = TextEditingController(
        text: f.lat?.toStringAsFixed(5) ?? '');
    _lon = TextEditingController(
        text: f.lon?.toStringAsFixed(5) ?? '');
    _pumpModel = TextEditingController(text: f.pumpModel ?? '');
    _pumpHp = TextEditingController(text: f.pumpHp ?? '');
    _filterType = TextEditingController(text: f.filterType ?? '');
    _filterInches = TextEditingController(text: f.filterInches ?? '');
    _filterModel = TextEditingController(text: f.filterModel ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _name, _lat, _lon, _pumpModel, _pumpHp,
      _filterType, _filterInches, _filterModel,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, {TextInputType? type}) {
    return TextFormField(
      controller: c,
      style: const TextStyle(color: kText),
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kText2),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kGreen),
        ),
        filled: true,
        fillColor: kCard,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final lat = double.tryParse(_lat.text.replaceAll(',', '.'));
    final lon = double.tryParse(_lon.text.replaceAll(',', '.'));
    if (_lat.text.trim().isNotEmpty && lat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Latitud inválida')));
      return;
    }
    if (_lon.text.trim().isNotEmpty && lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Longitud inválida')));
      return;
    }
    setState(() => _saving = true);
    try {
      await CloudService.instance.updateField(
        widget.field.id,
        name: _name.text.trim(),
        lat: lat,
        lon: lon,
        pumpModel: _pumpModel.text.trim(),
        pumpHp: _pumpHp.text.trim(),
        filterType: _filterType.text.trim(),
        filterInches: _filterInches.text.trim(),
        filterModel: _filterModel.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDbg,
      appBar: AppBar(
        backgroundColor: kCard,
        foregroundColor: kText,
        title: const Text('Editar campo'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Guardar',
                style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_name, 'Nombre del campo'),
            const SizedBox(height: 12),
            _field(_lat, 'Latitud (opcional)',
                type: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            _field(_lon, 'Longitud (opcional)',
                type: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 20),
            const Text('Equipamiento',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kGreen)),
            const SizedBox(height: 10),
            _field(_pumpModel, 'Modelo de bomba'),
            const SizedBox(height: 12),
            _field(_pumpHp, 'Potencia de bomba (HP)'),
            const SizedBox(height: 12),
            _field(_filterType, 'Tipo de filtro'),
            const SizedBox(height: 12),
            _field(_filterInches, 'Filtro (pulgadas)'),
            const SizedBox(height: 12),
            _field(_filterModel, 'Modelo de filtro'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: kGreen),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}

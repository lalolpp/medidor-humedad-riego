/// Solicitud de acceso de una persona invitada por correo (o por QR/código).
/// Flujo: 'pending' (esperando aprobación del dueño) -> 'approved' | 'rejected'.
/// Al aprobar, el email se agrega a `fields/{id}.sharedWith` y a los `shares`
/// de los dispositivos del campo; al bloquear se revierte (status 'revoked').
class AccessRequest {
  final String id;
  final String ownerUid;
  final String fieldId;
  final String token;
  final String email;
  final String uid;
  final String status;
  final DateTime? requestedAt;
  final DateTime? decidedAt;

  const AccessRequest({
    required this.id,
    required this.ownerUid,
    required this.fieldId,
    required this.token,
    required this.email,
    required this.uid,
    required this.status,
    this.requestedAt,
    this.decidedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';

  factory AccessRequest.fromMap(String id, Map<String, dynamic> data) {
    return AccessRequest(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      fieldId: data['fieldId'] as String? ?? '',
      token: data['token'] as String? ?? '',
      email: data['email'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      requestedAt: data['requestedAt'] != null
          ? DateTime.tryParse(data['requestedAt'] as String)
          : null,
      decidedAt: data['decidedAt'] != null
          ? DateTime.tryParse(data['decidedAt'] as String)
          : null,
    );
  }
}

/// Códigos funcionales estables de POST /pedidos/con-items (backend ORD-SYNC-002-BE).
class OrderSyncBackendCodes {
  OrderSyncBackendCodes._();

  static const membershipInactive = 'MEMBERSHIP_INACTIVE';
  static const membershipUnavailable = 'MEMBERSHIP_UNAVAILABLE';
  static const clubInactive = 'CLUB_INACTIVE';
  static const clubUnavailable = 'CLUB_UNAVAILABLE';
  static const productUnavailable = 'ORDER_PRODUCT_UNAVAILABLE';
  static const comboUnavailable = 'ORDER_COMBO_UNAVAILABLE';
  static const optionInvalid = 'ORDER_OPTION_INVALID';
  static const invalidQuantity = 'ORDER_INVALID_QUANTITY';
  static const invalidRequest = 'ORDER_INVALID_REQUEST';
  static const clientIdConflict = 'ORDER_CLIENT_ID_CONFLICT';
  static const conflict = 'CONFLICT';

  static const Set<String> permanentCodes = {
    membershipInactive,
    membershipUnavailable,
    clubInactive,
    clubUnavailable,
    productUnavailable,
    comboUnavailable,
    optionInvalid,
    invalidQuantity,
    invalidRequest,
    clientIdConflict,
  };

  static const Set<String> notFoundPermanentCodes = {
    membershipUnavailable,
    clubUnavailable,
    productUnavailable,
    comboUnavailable,
  };
}

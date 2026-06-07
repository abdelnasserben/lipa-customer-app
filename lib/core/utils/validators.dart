/// Client-side input validation, derived from the Customer Frontend
/// Specification §6 (Request Schemas) plus two local business rules.
///
/// These checks exist to (a) block malformed/abusive input before it ever
/// reaches the API, and (b) avoid wasting a network round-trip when the input
/// could never satisfy the backend contract. The **server remains
/// authoritative** — every value is validated again server-side; these helpers
/// only catch obvious mistakes early and keep submit buttons disabled until the
/// shape is plausible.
///
/// Helpers come in two flavours:
///  - `isValidX(...)` → bool, for gating a submit button.
///  - `xError(...)`   → French message or null, for inline field errors.
library;

/// Strips every non-digit character. Phone/PIN/amount controllers hold
/// presentation text (spaces, grouping); the API always receives raw digits.
String digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

// ── Phone (Comorian local number) ────────────────────────────────────────
//
// Spec §6.1: phoneNumber is "digits, 4..15". Locally we know the Comorian
// mobile plan is exactly 7 digits and the two live operators (Telma / Huri)
// allocate ranges starting with 3 or 4. Enforcing that frontally rejects
// typos and clearly-invalid numbers without an API call.

/// The leading digits assigned to the two current Comorian mobile operators.
const Set<String> kComorianOperatorPrefixes = {'3', '4'};

/// A complete, well-formed Comorian local mobile number: exactly 7 digits
/// beginning with an active operator prefix (3 or 4).
bool isValidComorianPhone(String raw) {
  final d = digitsOnly(raw);
  return d.length == 7 && kComorianOperatorPrefixes.contains(d[0]);
}

/// Inline error for a Comorian phone field, or null when it's valid/empty.
/// Empty returns null so the field doesn't shout before the user types.
String? comorianPhoneError(String raw) {
  final d = digitsOnly(raw);
  if (d.isEmpty) return null;
  if (!kComorianOperatorPrefixes.contains(d[0])) {
    return 'Le numéro doit commencer par 3 ou 4.';
  }
  if (d.length < 7) return 'Le numéro doit comporter 7 chiffres.';
  if (d.length > 7) return 'Le numéro comporte trop de chiffres.';
  return null;
}

// ── PIN ──────────────────────────────────────────────────────────────────
//
// Spec §6.1: pin / currentPin / newPin are "digits, 4..8".

const int kPinMinLength = 4;
const int kPinMaxLength = 8;

/// A syntactically valid auth PIN: 4–8 digits, nothing else.
bool isValidPin(String pin) {
  if (pin.length < kPinMinLength || pin.length > kPinMaxLength) return false;
  return RegExp(r'^\d+$').hasMatch(pin);
}

/// Inline error for a single PIN field, or null when valid/empty.
String? pinError(String pin) {
  if (pin.isEmpty) return null;
  if (!RegExp(r'^\d+$').hasMatch(pin)) return 'Le PIN ne contient que des chiffres.';
  if (pin.length < kPinMinLength) return 'Le PIN doit comporter au moins 4 chiffres.';
  if (pin.length > kPinMaxLength) return 'Le PIN ne peut dépasser 8 chiffres.';
  return null;
}

/// Validates a PIN *change* as a whole (local business rules beyond the API
/// contract). Returns a French error or null when the change is acceptable:
///  - all three fields must be valid PINs;
///  - the new PIN and its confirmation must match;
///  - the new PIN must differ from the current one (changing a PIN to the
///    same value is pointless and the backend would reject it anyway).
String? pinChangeError({
  required String currentPin,
  required String newPin,
  required String confirmPin,
}) {
  if (!isValidPin(currentPin)) return 'Saisissez votre PIN actuel (4 à 8 chiffres).';
  if (!isValidPin(newPin)) return 'Le nouveau PIN doit comporter 4 à 8 chiffres.';
  if (newPin != confirmPin) return 'Les deux PIN ne correspondent pas.';
  if (newPin == currentPin) {
    return 'Le nouveau PIN doit être différent de l’actuel.';
  }
  return null;
}

/// True when a PIN change is ready to submit (used to enable the button).
bool isValidPinChange({
  required String currentPin,
  required String newPin,
  required String confirmPin,
}) =>
    pinChangeError(
      currentPin: currentPin,
      newPin: newPin,
      confirmPin: confirmPin,
    ) ==
    null;

/// Validates a PIN *setup* / reset (no current PIN, just new + confirm).
bool isValidPinSetup({required String newPin, required String confirmPin}) =>
    isValidPin(newPin) && newPin == confirmPin;

// ── Amount (KMF minor-unit integer) ───────────────────────────────────────
//
// Spec §6.2: P2P amount is "strictly positive"; bill amount is ">= 1". A
// service may additionally declare min/max bounds (see BillService).

/// A strictly-positive integer amount (optionally within [min, max]).
bool isValidAmount(int amount, {int? min, int? max}) {
  if (amount <= 0) return false;
  if (min != null && amount < min) return false;
  if (max != null && amount > max) return false;
  return true;
}

// ── TOTP / MFA code ───────────────────────────────────────────────────────
//
// Spec §6.1: code is "exactly 6 digits".

bool isValidTotpCode(String code) => RegExp(r'^\d{6}$').hasMatch(code);

// ── Bill reference ─────────────────────────────────────────────────────────
//
// Spec §6.2: reference is "not blank, max 100". Per-provider regex/length
// rules are checked by BillCatalogProvider.referenceLooksValid.

const int kReferenceMaxLength = 100;

bool isValidReference(String reference) {
  final r = reference.trim();
  return r.isNotEmpty && r.length <= kReferenceMaxLength;
}

// ── Payment-request short code ────────────────────────────────────────────
//
// Short codes are alphanumeric (entered upper-cased in the UI). We require at
// least 4 characters before allowing a lookup — the backend returns a uniform
// 404 for anything unknown, so we keep the floor low and let the server judge.

bool isValidShortCode(String code) =>
    RegExp(r'^[A-Z0-9]{4,10}$').hasMatch(code.trim().toUpperCase());

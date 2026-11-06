import '../../../l10n/generated/app_localizations.dart';
import '../../domain/model/valueobjects.dart';

/// Localized message of each validation error of the identity forms.
extension InvalidValueMessage on InvalidValueReason {
  String message(AppLocalizations l10n) => switch (this) {
    InvalidValueReason.nameRequired => l10n.validationNameRequired,
    InvalidValueReason.nameTooShort => l10n.validationNameTooShort,
    InvalidValueReason.nameTooLong => l10n.validationNameTooLong,
    InvalidValueReason.phoneRequired => l10n.validationPhoneRequired,
    InvalidValueReason.phoneInvalid => l10n.validationPhoneInvalid,
    InvalidValueReason.organizationRequired =>
      l10n.validationOrganizationRequired,
    InvalidValueReason.brigadeCodeRequired =>
      l10n.validationBrigadeCodeRequired,
    InvalidValueReason.brigadeCodeInvalid => l10n.validationBrigadeCodeInvalid,
  };
}

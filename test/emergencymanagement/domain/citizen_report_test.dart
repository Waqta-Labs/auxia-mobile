import 'package:auxia_mobile/emergencymanagement/domain/model/citizen_report.dart';
import 'package:auxia_mobile/shared/domain/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';

CitizenReport _report({
  EmergencyDetail detail = const EmergencyDetail(),
  GeoPoint? location,
  CitizenReportStatus status = CitizenReportStatus.saved,
}) => CitizenReport(
  id: 'r1',
  code: 'SR-0412',
  category: HelpCategory.medical,
  reportedAt: DateTime(2026, 11, 6, 9, 41),
  status: status,
  location: location,
  detail: detail,
);

void main() {
  test('a bare SOS says only the category', () {
    expect(_report().toReportText(), 'SOS Médico.');
  });

  test('the text describes people, access and location for the NLP', () {
    final report = _report(
      location: const GeoPoint(-12.04641, -77.04281),
      detail: const EmergencyDetail(
        children: 3,
        elderly: 1,
        injured: 2,
        accessConditions: {
          AccessCondition.noDrinkingWater,
          AccessCondition.roadBlocked,
        },
      ),
    );

    expect(
      report.toReportText(),
      'SOS Médico. Necesitan ayuda 3 niños, 1 adulto mayor y 2 heridos. '
      'Vía bloqueada y sin agua potable. '
      'Ubicación GPS -12.0464, -77.0428.',
    );
  });

  test('singular and single items read naturally', () {
    final report = _report(
      detail: const EmergencyDetail(
        children: 1,
        accessConditions: {AccessCondition.damagedBuilding},
      ),
    );

    expect(
      report.toReportText(),
      'SOS Médico. Necesitan ayuda 1 niño. Edificio dañado.',
    );
  });

  test('a late detail names the first report', () {
    final report = _report(
      detail: const EmergencyDetail(injured: 2),
      status: CitizenReportStatus.received,
    );

    expect(
      report.toFollowUpText(),
      'Detalle adicional del reporte SR-0412. '
      'SOS Médico. Necesitan ayuda 2 heridos.',
    );
  });

  test('only a saved report can still take the detail', () {
    expect(_report().isUnsent, isTrue);
    expect(_report(status: CitizenReportStatus.transmitting).isUnsent, isFalse);
  });

  test('each status fills its steps of the four step progress', () {
    expect(CitizenReportStatus.saved.completedSteps, 1);
    expect(CitizenReportStatus.transmitting.completedSteps, 2);
    expect(CitizenReportStatus.received.completedSteps, 2);
    expect(CitizenReportStatus.prioritized.completedSteps, 3);
    expect(CitizenReportStatus.brigadeOnTheWay.completedSteps, 4);
  });

  test('the detail knows when it is empty', () {
    expect(const EmergencyDetail().isEmpty, isTrue);
    expect(const EmergencyDetail(photoPath: '/p.jpg').isEmpty, isFalse);
  });
}

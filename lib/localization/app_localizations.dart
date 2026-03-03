import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:order_tracker/localization/translations.dart';

enum AppLanguage {
  arabic('ar', 'العربية'),
  bengali('bn', 'বাংলা'),
  english('en', 'English'),
  hindi('hi', 'हिन्दी'),
  nepali('ne', 'नेपाली'),
  filipino('fil', 'Filipino');

  final String code;
  final String nativeName;

  const AppLanguage(this.code, this.nativeName);

  Locale get locale => Locale(code);
}

class AppStrings {
  // الجلسات والبحث
  static const sessionsTitle = 'sessionsTitle';
  static const searchHint = 'searchHint';
  static const filtersTitle = 'filtersTitle';
  static const clearFilters = 'clearFilters';
  static const applyFilters = 'applyFilters';
  static const filterStation = 'filterStation';
  static const filterStationHint = 'filterStationHint';
  static const allStations = 'allStations';
  static const filterStatus = 'filterStatus';
  static const filterStatusAll = 'filterStatusAll';
  static const filterStatusOpen = 'filterStatusOpen';
  static const filterStatusPending = 'filterStatusPending';
  static const filterStatusClosed = 'filterStatusClosed';
  static const filterFuelType = 'filterFuelType';
  static const filterFuelTypeAll = 'filterFuelTypeAll';
  static const filterFuelType91 = 'filterFuelType91';
  static const filterFuelType95 = 'filterFuelType95';
  static const filterFuelTypeDiesel = 'filterFuelTypeDiesel';
  static const filterFuelTypeGas = 'filterFuelTypeGas';
  static const fromDate = 'fromDate';
  static const toDate = 'toDate';
  static const newSession = 'newSession';
  static const noExpensesAdded = 'noExpensesAdded';

  // الإعدادات والمستخدم
  static const logout = 'logout';
  static const languageLabel = 'languageLabel';
  static const languageDialogTitle = 'languageDialogTitle';

  // الورديات
  static const shiftCountdown = 'shiftCountdown';
  static const shiftExpiredTitle = 'shiftExpiredTitle';
  static const shiftExpiredMessage = 'shiftExpiredMessage';
  static const timeLeftUntilShiftEnds = 'timeLeftUntilShiftEnds';
  static const shiftTimeHasEnded = 'shiftTimeHasEnded';
  static const pleaseCloseAndHandover = 'pleaseCloseAndHandover';

  // القراءات
  static const openingTotalLabel = 'openingTotalLabel';
  static const closingTotalLabel = 'closingTotalLabel';
  static const openingReadingLabel = 'openingReadingLabel';
  static const closingReadingLabel = 'closingReadingLabel';
  static const openingReadingDetail = 'openingReadingDetail';
  static const openingReadingLabelShort = 'openingReadingLabelShort';
  static const closingReadingLabelShort = 'closingReadingLabelShort';
  static const readingEntryPending = 'readingEntryPending';

  // الجلسات العامة
  static const noSessions = 'noSessions';
  static const viewDetails = 'viewDetails';
  static const closeSession = 'closeSession';
  static const closingSessionSuccess = 'closingSessionSuccess';
  static const closeSessionError = 'closeSessionError';
  static const closingSessionLoading = 'closingSessionLoading';
  static const notesLabel = 'notesLabel';

  // فتح الجلسة
  static const openSessionTitle = 'openSessionTitle';
  static const sessionInfoTitle = 'sessionInfoTitle';
  static const sessionDateTimeLabel = 'sessionDateTimeLabel';
  static const openSessionButton = 'openSessionButton';
  static const openSessionSuccess = 'openSessionSuccess';
  static const loadingOpeningSession = 'loadingOpeningSession';
  static const stationStockTitle = 'stationStockTitle';
  static const stockAvailableLabel = 'stockAvailableLabel';
  static const stockYesterdayLabel = 'stockYesterdayLabel';
  static const stationStockNoData = 'stationStockNoData';

  // المحطة
  static const assignedStationLabel = 'assignedStationLabel';
  static const selectStation = 'selectStation';
  static const selectStationHint = 'selectStationHint';
  static const selectStationAndPump = 'selectStationAndPump';
  static const noPumpsForStation = 'noPumpsForStation';

  // الطلمبات
  static const selectPump = 'selectPump';
  static const selectNextPump = 'selectNextPump';
  static const activatePumpSlots = 'activatePumpSlots';
  static const pumpFuelLabel = 'pumpFuelLabel';

  // الوردية
  static const shiftLabel = 'shiftLabel';
  static const shiftTypeMorning = 'shiftTypeMorning';
  static const shiftTypeEvening = 'shiftTypeEvening';

  // القراءات والمقاييس
  static const meterReadingLabel = 'meterReadingLabel';
  static const enterReading = 'enterReading';
  static const readingMustBeNumber = 'readingMustBeNumber';
  static const openingReadingsTitle = 'openingReadingsTitle';
  static const closingReadingsTitle = 'closingReadingsTitle';

  // الصور
  static const attachMeterImage = 'attachMeterImage';
  static const changeImage = 'changeImage';
  static const imageAttached = 'imageAttached';
  static const awaitingImage = 'awaitingImage';
  static const attachNozzleImage = 'attachNozzleImage';
  static const attachClosingImageForNozzle = 'attachClosingImageForNozzle';

  // الفتحات (Nozzles)
  static const sideLeft = 'sideLeft';
  static const sideRight = 'sideRight';
  static const fuelTypeLabel = 'fuelTypeLabel';
  static const invalidNozzleReading = 'invalidNozzleReading';
  static const nozzleLabel = 'nozzleLabel';
  static const closingNozzleLabel = 'closingNozzleLabel';
  static const nozzleCountTitle = 'nozzleCountTitle';
  static const nozzleCountLabel = 'nozzleCountLabel';

  // القراءات الإغلاق
  static const enterClosingReading = 'enterClosingReading';
  static const enterClosingReadingForNozzle = 'enterClosingReadingForNozzle';

  // أسباب الفرق
  static const differenceReasonOptional = 'differenceReasonOptional';
  static const differenceReasonNormal = 'differenceReasonNormal';
  static const differenceReasonVentilation = 'differenceReasonVentilation';
  static const differenceReasonLeak = 'differenceReasonLeak';
  static const differenceReasonReadingError = 'differenceReasonReadingError';
  static const differenceReasonOther = 'differenceReasonOther';

  // أخرى
  static const unexpectedError = 'unexpectedError';
  static const quantityLabel = 'quantityLabel';


  // ============= عناصر الجدول =============
  static const sessionNumberColumn = 'sessionNumberColumn';
  static const stationColumn = 'stationColumn';
  static const pumpColumn = 'pumpColumn';
  static const statusColumn = 'statusColumn';
  static const openingClosingReadingsColumn = 'openingClosingReadingsColumn';
  static const soldQuantityColumn = 'soldQuantityColumn';
  static const differenceColumn = 'differenceColumn';
  static const fuelPricesColumn = 'fuelPricesColumn';
  static const employeeColumn = 'employeeColumn';
  static const amountColumn = 'amountColumn';
  static const shiftColumn = 'shiftColumn';
  static const dateColumn = 'dateColumn';
  static const actionsColumn = 'actionsColumn';

  // ============= الأزرار والإجراءات =============
  static const closeSessionTooltip = 'closeSessionTooltip';
  static const viewDetailsTooltip = 'viewDetailsTooltip';
  static const openNewSessionHint = 'openNewSessionHint';
  static const filterListTooltip = 'filterListTooltip';
  static const languageTooltip = 'languageTooltip';
  static const logoutTooltip = 'logoutTooltip';

  // ============= عناصر البطاقة =============
  static const litersPricePerFuelType = 'litersPricePerFuelType';
  static const fuelPriceUnavailable = 'fuelPriceUnavailable';
  static const totalOpeningReading = 'totalOpeningReading';
  static const totalClosingReading = 'totalClosingReading';
  static const literPrice = 'literPrice';
  static const soldQuantity = 'soldQuantity';
  static const liters = 'liters';
  static const readingsColumn = 'readingsColumn';
  static const quantity = 'quantity';
  static const amount = 'amount';
  static const fuelType = 'fuelType';
  static const expectedAmount = 'expectedAmount';

  // ============= القوالب =============
  static const pumpNozzleFuelTemplate = 'pumpNozzleFuelTemplate';
  static const pumpNozzleTemplate = 'pumpNozzleTemplate';
  static const openingReadingTemplate = 'openingReadingTemplate';
  static const formatTemplate = 'formatTemplate';
  static const differenceTemplate = 'differenceTemplate';

  // ============= حالات الجلسة =============
  static const statusOpen = 'statusOpen';
  static const statusClosed = 'statusClosed';
  static const statusApproved = 'statusApproved';
  static const statusUndefined = 'statusUndefined';

  // ============= العملة والمفاصل =============
  static const currencySaudiRiyal = 'currencySaudiRiyal';
  static const pumpSeparator = 'pumpSeparator';
  static const fuelTypeSeparator = 'fuelTypeSeparator';


    static const closeSessionTitle = 'closeSessionTitle';
  static const enterValidNumber = 'enterValidNumber';
  static const mustBeGreaterThanOpening = 'mustBeGreaterThanOpening';
  static const attachClosingMeterImage = 'attachClosingMeterImage';
  static const imageAttachedSuccess = 'imageAttachedSuccess';
  static const totalLiters = 'totalLiters';
  static const paymentTypesTitle = 'paymentTypesTitle';
  static const cashLabel = 'cashLabel';
  static const cardLabel = 'cardLabel';
  static const madaLabel = 'madaLabel';
  static const otherLabel = 'otherLabel';
  static const totalSales = 'totalSales';
  static const sumOfAllPayments = 'sumOfAllPayments';
  static const expensesTitle = 'expensesTitle';
  static const expenseType = 'expenseType';
  static const expenseAmount = 'expenseAmount';
  static const expenseNotesOptional = 'expenseNotesOptional';
  static const addExpense = 'addExpense';
  static const fuelSupplyTitle = 'fuelSupplyTitle';
  static const fuelSupplyInfo = 'fuelSupplyInfo';
  static const fuelQuantity = 'fuelQuantity';
  static const tankerNumber = 'tankerNumber';
  static const supplierName = 'supplierName';
  static const balanceAndDifferenceTitle = 'balanceAndDifferenceTitle';
  static const carriedForwardBalance = 'carriedForwardBalance';
  static const calculatedDifference = 'calculatedDifference';
  static const salesGreaterThanExpected = 'salesGreaterThanExpected';
  static const salesLessThanExpected = 'salesLessThanExpected';
  static const salesIncrease = 'salesIncrease';
  static const salesShortage = 'salesShortage';
  static const differenceReasonLabel = 'differenceReasonLabel';
  static const additionalNotes = 'additionalNotes';
  static const multipleFuelTypes = 'multipleFuelTypes';
  static const openingDate = 'openingDate';
  static const openingEmployee = 'openingEmployee';
  static const vehicleLitersBreakdown = 'vehicleLitersBreakdown';
  static const loadingClosingSession = 'loadingClosingSession';



  // ============= العملة =============
  static const currencySAR = 'currencySAR';
  static const currencyLiters = 'currencyLiters';

  // ============= الصيغ =============
  static const litersTemplate = 'litersTemplate';
  static const amountTemplate = 'amountTemplate';

}

class AppLocalizations {
  final AppLanguage language;

  const AppLocalizations(this.language);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String translate(String key, [Map<String, String>? params]) {
    final value =
        translationValues[key]?[language.code] ??
        translationValues[key]?['ar'] ??
        key;
    if (params == null || params.isEmpty) return value;

    var formatted = value;
    params.forEach((paramKey, paramValue) {
      formatted = formatted.replaceAll('{$paramKey}', paramValue);
    });
    return formatted;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLanguage.values.map((lang) => lang.code).contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    final language = AppLanguage.values.firstWhere(
      (lang) => lang.code == locale.languageCode,
      orElse: () => AppLanguage.arabic,
    );
    return SynchronousFuture(AppLocalizations(language));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension LocalizationHelpers on BuildContext {
  String tr(String key, [Map<String, String>? params]) =>
      AppLocalizations.of(this).translate(key, params);
}

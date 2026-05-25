import CoreLocation

/// Approximate geographic centroid of every ISO-3166-1 alpha-2 country we plot
/// on the world map. Numbers are rough land-mass centroids — accurate enough
/// for "case dot near the country" rendering at world zoom.
///
/// Coverage: every UN member state (193) + UN observers (Vatican, Palestine)
/// + de-facto independent (Taiwan, Kosovo) + populated dependencies most
/// likely to appear in surveillance feeds (Bermuda, Cayman, Faroe, Greenland,
/// Hong Kong, Macao, etc).
enum CountryCentroids {
    static func coordinate(for isoCode: String) -> CLLocationCoordinate2D? {
        Self.table[isoCode.uppercased()]
    }

    private static let table: [String: CLLocationCoordinate2D] = [
        // MARK: Americas
        "AG": .init(latitude:  17.1,  longitude:  -61.8),  // Antigua and Barbuda
        "AR": .init(latitude: -38.4,  longitude:  -63.6),  // Argentina
        "BB": .init(latitude:  13.2,  longitude:  -59.5),  // Barbados
        "BM": .init(latitude:  32.3,  longitude:  -64.8),  // Bermuda
        "BO": .init(latitude: -16.3,  longitude:  -63.6),  // Bolivia
        "BR": .init(latitude: -10.0,  longitude:  -52.0),  // Brazil
        "BS": .init(latitude:  25.0,  longitude:  -77.4),  // Bahamas
        "BZ": .init(latitude:  17.2,  longitude:  -88.5),  // Belize
        "CA": .init(latitude:  56.0,  longitude:  -96.0),  // Canada
        "CL": .init(latitude: -35.7,  longitude:  -71.5),  // Chile
        "CO": .init(latitude:   4.6,  longitude:  -74.3),  // Colombia
        "CR": .init(latitude:   9.7,  longitude:  -83.8),  // Costa Rica
        "CU": .init(latitude:  21.5,  longitude:  -77.8),  // Cuba
        "DM": .init(latitude:  15.4,  longitude:  -61.4),  // Dominica
        "DO": .init(latitude:  18.7,  longitude:  -70.2),  // Dominican Republic
        "EC": .init(latitude:  -1.8,  longitude:  -78.2),  // Ecuador
        "GD": .init(latitude:  12.1,  longitude:  -61.7),  // Grenada
        "GL": .init(latitude:  71.7,  longitude:  -42.6),  // Greenland
        "GT": .init(latitude:  15.8,  longitude:  -90.2),  // Guatemala
        "GY": .init(latitude:   4.9,  longitude:  -58.9),  // Guyana
        "HN": .init(latitude:  15.2,  longitude:  -86.2),  // Honduras
        "HT": .init(latitude:  19.0,  longitude:  -72.3),  // Haiti
        "JM": .init(latitude:  18.1,  longitude:  -77.3),  // Jamaica
        "KN": .init(latitude:  17.4,  longitude:  -62.8),  // Saint Kitts and Nevis
        "KY": .init(latitude:  19.5,  longitude:  -80.5),  // Cayman Islands
        "LC": .init(latitude:  13.9,  longitude:  -61.0),  // Saint Lucia
        "MX": .init(latitude:  23.6,  longitude: -102.5),  // Mexico
        "NI": .init(latitude:  12.9,  longitude:  -85.2),  // Nicaragua
        "PA": .init(latitude:   8.5,  longitude:  -80.8),  // Panama
        "PE": .init(latitude:  -9.2,  longitude:  -75.0),  // Peru
        "PR": .init(latitude:  18.2,  longitude:  -66.6),  // Puerto Rico
        "PY": .init(latitude: -23.4,  longitude:  -58.4),  // Paraguay
        "SR": .init(latitude:   3.9,  longitude:  -56.0),  // Suriname
        "SV": .init(latitude:  13.8,  longitude:  -88.9),  // El Salvador
        "TT": .init(latitude:  10.7,  longitude:  -61.2),  // Trinidad and Tobago
        "US": .init(latitude:  39.5,  longitude:  -98.5),  // United States
        "UY": .init(latitude: -32.5,  longitude:  -55.8),  // Uruguay
        "VC": .init(latitude:  13.3,  longitude:  -61.2),  // Saint Vincent and the Grenadines
        "VE": .init(latitude:   6.4,  longitude:  -66.6),  // Venezuela

        // MARK: Europe
        "AD": .init(latitude:  42.5,  longitude:    1.5),  // Andorra
        "AL": .init(latitude:  41.2,  longitude:   20.2),  // Albania
        "AT": .init(latitude:  47.5,  longitude:   14.6),  // Austria
        "BA": .init(latitude:  43.9,  longitude:   17.7),  // Bosnia and Herzegovina
        "BE": .init(latitude:  50.5,  longitude:    4.5),  // Belgium
        "BG": .init(latitude:  42.7,  longitude:   25.5),  // Bulgaria
        "BY": .init(latitude:  53.7,  longitude:   28.0),  // Belarus
        "CH": .init(latitude:  46.8,  longitude:    8.2),  // Switzerland
        "CY": .init(latitude:  35.1,  longitude:   33.4),  // Cyprus
        "CZ": .init(latitude:  49.8,  longitude:   15.5),  // Czechia
        "DE": .init(latitude:  51.2,  longitude:   10.4),  // Germany
        "DK": .init(latitude:  56.0,  longitude:    9.5),  // Denmark
        "EE": .init(latitude:  58.6,  longitude:   25.0),  // Estonia
        "ES": .init(latitude:  40.5,  longitude:   -3.7),  // Spain
        "FI": .init(latitude:  64.5,  longitude:   26.0),  // Finland
        "FO": .init(latitude:  62.0,  longitude:   -6.8),  // Faroe Islands
        "FR": .init(latitude:  46.6,  longitude:    2.2),  // France
        "GB": .init(latitude:  54.5,  longitude:   -2.5),  // United Kingdom
        "GE": .init(latitude:  42.3,  longitude:   43.4),  // Georgia
        "GR": .init(latitude:  39.0,  longitude:   22.0),  // Greece
        "HR": .init(latitude:  45.1,  longitude:   15.2),  // Croatia
        "HU": .init(latitude:  47.2,  longitude:   19.5),  // Hungary
        "IE": .init(latitude:  53.4,  longitude:   -8.2),  // Ireland
        "IS": .init(latitude:  64.9,  longitude:  -19.0),  // Iceland
        "IT": .init(latitude:  42.8,  longitude:   12.6),  // Italy
        "LI": .init(latitude:  47.2,  longitude:    9.5),  // Liechtenstein
        "LT": .init(latitude:  55.2,  longitude:   23.9),  // Lithuania
        "LU": .init(latitude:  49.8,  longitude:    6.1),  // Luxembourg
        "LV": .init(latitude:  56.9,  longitude:   24.6),  // Latvia
        "MC": .init(latitude:  43.7,  longitude:    7.4),  // Monaco
        "MD": .init(latitude:  47.4,  longitude:   28.4),  // Moldova
        "ME": .init(latitude:  42.7,  longitude:   19.4),  // Montenegro
        "MK": .init(latitude:  41.6,  longitude:   21.7),  // North Macedonia
        "MT": .init(latitude:  35.9,  longitude:   14.4),  // Malta
        "NL": .init(latitude:  52.1,  longitude:    5.3),  // Netherlands
        "NO": .init(latitude:  64.5,  longitude:   17.4),  // Norway
        "PL": .init(latitude:  52.0,  longitude:   19.1),  // Poland
        "PT": .init(latitude:  39.6,  longitude:   -8.0),  // Portugal
        "RO": .init(latitude:  45.9,  longitude:   24.9),  // Romania
        "RS": .init(latitude:  44.0,  longitude:   21.0),  // Serbia
        "RU": .init(latitude:  61.5,  longitude:  105.0),  // Russia
        "SE": .init(latitude:  62.0,  longitude:   15.0),  // Sweden
        "SI": .init(latitude:  46.1,  longitude:   14.8),  // Slovenia
        "SK": .init(latitude:  48.7,  longitude:   19.7),  // Slovakia
        "SM": .init(latitude:  43.9,  longitude:   12.5),  // San Marino
        "UA": .init(latitude:  48.4,  longitude:   31.2),  // Ukraine
        "VA": .init(latitude:  41.9,  longitude:   12.5),  // Vatican
        "XK": .init(latitude:  42.6,  longitude:   20.9),  // Kosovo

        // MARK: Africa
        "AO": .init(latitude: -11.2,  longitude:   17.9),  // Angola
        "BF": .init(latitude:  12.2,  longitude:   -1.6),  // Burkina Faso
        "BI": .init(latitude:  -3.4,  longitude:   29.9),  // Burundi
        "BJ": .init(latitude:   9.3,  longitude:    2.3),  // Benin
        "BW": .init(latitude: -22.3,  longitude:   24.7),  // Botswana
        "CD": .init(latitude:  -4.0,  longitude:   21.8),  // DR Congo
        "CF": .init(latitude:   6.6,  longitude:   20.9),  // Central African Republic
        "CG": .init(latitude:  -0.2,  longitude:   15.8),  // Republic of the Congo
        "CI": .init(latitude:   7.5,  longitude:   -5.5),  // Côte d'Ivoire
        "CM": .init(latitude:   7.4,  longitude:   12.4),  // Cameroon
        "CV": .init(latitude:  16.5,  longitude:  -23.0),  // Cape Verde
        "DJ": .init(latitude:  11.8,  longitude:   42.6),  // Djibouti
        "DZ": .init(latitude:  28.0,  longitude:    1.7),  // Algeria
        "EG": .init(latitude:  26.8,  longitude:   30.8),  // Egypt
        "EH": .init(latitude:  24.2,  longitude:  -12.9),  // Western Sahara
        "ER": .init(latitude:  15.2,  longitude:   39.8),  // Eritrea
        "ET": .init(latitude:   9.1,  longitude:   40.5),  // Ethiopia
        "GA": .init(latitude:  -0.8,  longitude:   11.6),  // Gabon
        "GH": .init(latitude:   7.9,  longitude:   -1.0),  // Ghana
        "GM": .init(latitude:  13.4,  longitude:  -15.5),  // Gambia
        "GN": .init(latitude:   9.9,  longitude:  -10.0),  // Guinea
        "GQ": .init(latitude:   1.7,  longitude:   10.3),  // Equatorial Guinea
        "GW": .init(latitude:  11.8,  longitude:  -15.2),  // Guinea-Bissau
        "KE": .init(latitude:   0.0,  longitude:   37.9),  // Kenya
        "KM": .init(latitude: -11.9,  longitude:   43.9),  // Comoros
        "LR": .init(latitude:   6.4,  longitude:   -9.4),  // Liberia
        "LS": .init(latitude: -29.6,  longitude:   28.2),  // Lesotho
        "LY": .init(latitude:  26.3,  longitude:   17.2),  // Libya
        "MA": .init(latitude:  31.8,  longitude:   -7.1),  // Morocco
        "MG": .init(latitude: -18.8,  longitude:   46.9),  // Madagascar
        "ML": .init(latitude:  17.6,  longitude:   -4.0),  // Mali
        "MR": .init(latitude:  21.0,  longitude:  -10.9),  // Mauritania
        "MU": .init(latitude: -20.3,  longitude:   57.6),  // Mauritius
        "MW": .init(latitude: -13.3,  longitude:   34.3),  // Malawi
        "MZ": .init(latitude: -18.7,  longitude:   35.5),  // Mozambique
        "NA": .init(latitude: -22.9,  longitude:   18.5),  // Namibia
        "NE": .init(latitude:  17.6,  longitude:    8.1),  // Niger
        "NG": .init(latitude:   9.1,  longitude:    8.7),  // Nigeria
        "RW": .init(latitude:  -1.9,  longitude:   29.9),  // Rwanda
        "SC": .init(latitude:  -4.7,  longitude:   55.5),  // Seychelles
        "SD": .init(latitude:  12.9,  longitude:   30.2),  // Sudan
        "SL": .init(latitude:   8.5,  longitude:  -11.8),  // Sierra Leone
        "SN": .init(latitude:  14.5,  longitude:  -14.5),  // Senegal
        "SO": .init(latitude:   5.2,  longitude:   46.2),  // Somalia
        "SS": .init(latitude:   6.9,  longitude:   31.3),  // South Sudan
        "ST": .init(latitude:   0.2,  longitude:    6.6),  // São Tomé and Príncipe
        "SZ": .init(latitude: -26.5,  longitude:   31.5),  // Eswatini
        "TD": .init(latitude:  15.5,  longitude:   18.7),  // Chad
        "TG": .init(latitude:   8.6,  longitude:    0.8),  // Togo
        "TN": .init(latitude:  33.9,  longitude:    9.5),  // Tunisia
        "TZ": .init(latitude:  -6.4,  longitude:   34.9),  // Tanzania
        "UG": .init(latitude:   1.4,  longitude:   32.3),  // Uganda
        "ZA": .init(latitude: -30.6,  longitude:   22.9),  // South Africa
        "ZM": .init(latitude: -13.1,  longitude:   27.8),  // Zambia
        "ZW": .init(latitude: -19.0,  longitude:   29.2),  // Zimbabwe

        // MARK: Middle East
        "AE": .init(latitude:  23.4,  longitude:   53.8),  // UAE
        "AM": .init(latitude:  40.1,  longitude:   45.0),  // Armenia
        "AZ": .init(latitude:  40.1,  longitude:   47.6),  // Azerbaijan
        "BH": .init(latitude:  26.0,  longitude:   50.6),  // Bahrain
        "IL": .init(latitude:  31.0,  longitude:   34.9),  // Israel
        "IQ": .init(latitude:  33.2,  longitude:   43.7),  // Iraq
        "IR": .init(latitude:  32.4,  longitude:   53.7),  // Iran
        "JO": .init(latitude:  30.6,  longitude:   36.2),  // Jordan
        "KW": .init(latitude:  29.3,  longitude:   47.5),  // Kuwait
        "LB": .init(latitude:  33.9,  longitude:   35.9),  // Lebanon
        "OM": .init(latitude:  21.5,  longitude:   55.9),  // Oman
        "PS": .init(latitude:  31.9,  longitude:   35.2),  // Palestine
        "QA": .init(latitude:  25.4,  longitude:   51.2),  // Qatar
        "SA": .init(latitude:  23.9,  longitude:   45.1),  // Saudi Arabia
        "SY": .init(latitude:  34.8,  longitude:   38.9),  // Syria
        "TR": .init(latitude:  39.0,  longitude:   35.2),  // Turkey
        "YE": .init(latitude:  15.6,  longitude:   48.5),  // Yemen

        // MARK: Asia
        "AF": .init(latitude:  33.9,  longitude:   67.7),  // Afghanistan
        "BD": .init(latitude:  23.7,  longitude:   90.4),  // Bangladesh
        "BN": .init(latitude:   4.5,  longitude:  114.7),  // Brunei
        "BT": .init(latitude:  27.5,  longitude:   90.4),  // Bhutan
        "CN": .init(latitude:  35.9,  longitude:  104.2),  // China
        "HK": .init(latitude:  22.3,  longitude:  114.2),  // Hong Kong
        "ID": .init(latitude:  -2.5,  longitude:  118.0),  // Indonesia
        "IN": .init(latitude:  20.6,  longitude:   78.9),  // India
        "JP": .init(latitude:  36.2,  longitude:  138.3),  // Japan
        "KG": .init(latitude:  41.2,  longitude:   74.8),  // Kyrgyzstan
        "KH": .init(latitude:  12.6,  longitude:  104.9),  // Cambodia
        "KP": .init(latitude:  40.3,  longitude:  127.5),  // North Korea
        "KR": .init(latitude:  35.9,  longitude:  127.8),  // South Korea
        "KZ": .init(latitude:  48.0,  longitude:   66.9),  // Kazakhstan
        "LA": .init(latitude:  19.9,  longitude:  102.5),  // Laos
        "LK": .init(latitude:   7.9,  longitude:   80.8),  // Sri Lanka
        "MM": .init(latitude:  21.9,  longitude:   95.9),  // Myanmar
        "MN": .init(latitude:  46.9,  longitude:  103.8),  // Mongolia
        "MO": .init(latitude:  22.2,  longitude:  113.5),  // Macao
        "MV": .init(latitude:   3.2,  longitude:   73.2),  // Maldives
        "MY": .init(latitude:   4.2,  longitude:  101.9),  // Malaysia
        "NP": .init(latitude:  28.4,  longitude:   84.1),  // Nepal
        "PH": .init(latitude:  12.9,  longitude:  121.8),  // Philippines
        "PK": .init(latitude:  30.4,  longitude:   69.3),  // Pakistan
        "SG": .init(latitude:   1.4,  longitude:  103.8),  // Singapore
        "TH": .init(latitude:  15.9,  longitude:  100.9),  // Thailand
        "TJ": .init(latitude:  38.9,  longitude:   71.3),  // Tajikistan
        "TL": .init(latitude:  -8.9,  longitude:  125.7),  // Timor-Leste
        "TM": .init(latitude:  38.9,  longitude:   59.6),  // Turkmenistan
        "TW": .init(latitude:  23.7,  longitude:  121.0),  // Taiwan
        "UZ": .init(latitude:  41.4,  longitude:   64.6),  // Uzbekistan
        "VN": .init(latitude:  14.1,  longitude:  108.3),  // Vietnam

        // MARK: Oceania
        "AU": .init(latitude: -25.3,  longitude:  133.8),  // Australia
        "FJ": .init(latitude: -17.7,  longitude:  178.1),  // Fiji
        "FM": .init(latitude:   7.4,  longitude:  150.6),  // Micronesia
        "KI": .init(latitude:  -3.4,  longitude:  168.7),  // Kiribati
        "MH": .init(latitude:   7.1,  longitude:  171.2),  // Marshall Islands
        "NR": .init(latitude:  -0.5,  longitude:  166.9),  // Nauru
        "NZ": .init(latitude: -41.0,  longitude:  174.0),  // New Zealand
        "PG": .init(latitude:  -6.3,  longitude:  143.9),  // Papua New Guinea
        "PW": .init(latitude:   7.5,  longitude:  134.6),  // Palau
        "SB": .init(latitude:  -9.6,  longitude:  160.2),  // Solomon Islands
        "TO": .init(latitude: -21.2,  longitude: -175.2),  // Tonga
        "TV": .init(latitude:  -7.1,  longitude:  177.6),  // Tuvalu
        "VU": .init(latitude: -15.4,  longitude:  166.9),  // Vanuatu
        "WS": .init(latitude: -13.8,  longitude: -172.1)   // Samoa
    ]
}

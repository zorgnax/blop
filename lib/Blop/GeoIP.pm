# based on
# http://search.cpan.org/~borisz/Geo-IP-PurePerl-1.25/lib/Geo/IP/PurePerl.pm
# uses maxmind country, city, and isp databases at
# http://dev.maxmind.com/geoip/legacy/geolite/

package Blop::GeoIP;
use strict;
use warnings;
use Encode;

our $FULL_RECORD_LENGTH = 50;
our $STRUCTURE_INFO_MAX_SIZE = 20;
our $DATABASE_INFO_MAX_SIZE = 100;
our $GEOIP_REGION_EDITION_REV0 = 7;
our $GEOIP_STATE_BEGIN_REV0 = 16700000;
our $GEOIP_REGION_EDITION_REV1 = 3;
our $GEOIP_STATE_BEGIN_REV1 = 16000000;
our $GEOIP_COUNTRY_BEGIN = 16776960;
our $GEOIP_CITY_EDITION_REV0 = 6;
our $GEOIP_CITY_EDITION_REV1 = 2;
our $GEOIP_ORG_EDITION = 5;
our $GEOIP_ASNUM_EDITION = 9;
our $GEOIP_DOMAIN_EDITION = 11;
our $GEOIP_ISP_EDITION = 4;
our $GEOIP_COUNTRY_EDITION = 1;
our $GEOIP_NETSPEED_EDITION = 10;
our $STANDARD_RECORD_LENGTH = 3;
our $SEGMENT_RECORD_LENGTH = 3;
our $ORG_RECORD_LENGTH = 4;
our $MAX_ORG_RECORD_LENGTH = 300;

our @countries = (undef, "AP", "EU", "AD", "AE", "AF", "AG", "AI", "AL", "AM", "AN", "AO", "AQ", "AR", "AS", "AT", "AU", "AW", "AZ", "BA", "BB", "BD", "BE", "BF", "BG", "BH", "BI", "BJ", "BM", "BN", "BO", "BR", "BS", "BT", "BV", "BW", "BY", "BZ", "CA", "CC", "CD", "CF", "CG", "CH", "CI", "CK", "CL", "CM", "CN", "CO", "CR", "CU", "CV", "CX", "CY", "CZ", "DE", "DJ", "DK", "DM", "DO", "DZ", "EC", "EE", "EG", "EH", "ER", "ES", "ET", "FI", "FJ", "FK", "FM", "FO", "FR", "FX", "GA", "GB", "GD", "GE", "GF", "GH", "GI", "GL", "GM", "GN", "GP", "GQ", "GR", "GS", "GT", "GU", "GW", "GY", "HK", "HM", "HN", "HR", "HT", "HU", "ID", "IE", "IL", "IN", "IO", "IQ", "IR", "IS", "IT", "JM", "JO", "JP", "KE", "KG", "KH", "KI", "KM", "KN", "KP", "KR", "KW", "KY", "KZ", "LA", "LB", "LC", "LI", "LK", "LR", "LS", "LT", "LU", "LV", "LY", "MA", "MC", "MD", "MG", "MH", "MK", "ML", "MM", "MN", "MO", "MP", "MQ", "MR", "MS", "MT", "MU", "MV", "MW", "MX", "MY", "MZ", "NA", "NC", "NE", "NF", "NG", "NI", "NL", "NO", "NP", "NR", "NU", "NZ", "OM", "PA", "PE", "PF", "PG", "PH", "PK", "PL", "PM", "PN", "PR", "PS", "PT", "PW", "PY", "QA", "RE", "RO", "RU", "RW", "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SJ", "SK", "SL", "SM", "SN", "SO", "SR", "ST", "SV", "SY", "SZ", "TC", "TD", "TF", "TG", "TH", "TJ", "TK", "TM", "TN", "TO", "TL", "TR", "TT", "TV", "TW", "TZ", "UA", "UG", "UM", "US", "UY", "UZ", "VA", "VC", "VE", "VG", "VI", "VN", "VU", "WF", "WS", "YE", "YT", "RS", "ZA", "ZM", "ME", "ZW", "A1", "A2", "O1", "AX", "GG", "IM", "JE", "BL", "MF");

our @country_names = (undef, "Asia/Pacific Region", "Europe", "Andorra", "United Arab Emirates", "Afghanistan", "Antigua and Barbuda", "Anguilla", "Albania", "Armenia", "Netherlands Antilles", "Angola", "Antarctica", "Argentina", "American Samoa", "Austria", "Australia", "Aruba", "Azerbaijan", "Bosnia and Herzegovina", "Barbados", "Bangladesh", "Belgium", "Burkina Faso", "Bulgaria", "Bahrain", "Burundi", "Benin", "Bermuda", "Brunei Darussalam", "Bolivia", "Brazil", "Bahamas", "Bhutan", "Bouvet Island", "Botswana", "Belarus", "Belize", "Canada", "Cocos (Keeling) Islands", "Congo, The Democratic Republic of the", "Central African Republic", "Congo", "Switzerland", "Cote D'Ivoire", "Cook Islands", "Chile", "Cameroon", "China", "Colombia", "Costa Rica", "Cuba", "Cape Verde", "Christmas Island", "Cyprus", "Czech Republic", "Germany", "Djibouti", "Denmark", "Dominica", "Dominican Republic", "Algeria", "Ecuador", "Estonia", "Egypt", "Western Sahara", "Eritrea", "Spain", "Ethiopia", "Finland", "Fiji", "Falkland Islands (Malvinas)", "Micronesia, Federated States of", "Faroe Islands", "France", "France, Metropolitan", "Gabon", "United Kingdom", "Grenada", "Georgia", "French Guiana", "Ghana", "Gibraltar", "Greenland", "Gambia", "Guinea", "Guadeloupe", "Equatorial Guinea", "Greece", "South Georgia and the South Sandwich Islands", "Guatemala", "Guam", "Guinea-Bissau", "Guyana", "Hong Kong", "Heard Island and McDonald Islands", "Honduras", "Croatia", "Haiti", "Hungary", "Indonesia", "Ireland", "Israel", "India", "British Indian Ocean Territory", "Iraq", "Iran, Islamic Republic of", "Iceland", "Italy", "Jamaica", "Jordan", "Japan", "Kenya", "Kyrgyzstan", "Cambodia", "Kiribati", "Comoros", "Saint Kitts and Nevis", "Korea, Democratic People's Republic of", "Korea, Republic of", "Kuwait", "Cayman Islands", "Kazakhstan", "Lao People's Democratic Republic", "Lebanon", "Saint Lucia", "Liechtenstein", "Sri Lanka", "Liberia", "Lesotho", "Lithuania", "Luxembourg", "Latvia", "Libyan Arab Jamahiriya", "Morocco", "Monaco", "Moldova, Republic of", "Madagascar", "Marshall Islands", "Macedonia", "Mali", "Myanmar", "Mongolia", "Macau", "Northern Mariana Islands", "Martinique", "Mauritania", "Montserrat", "Malta", "Mauritius", "Maldives", "Malawi", "Mexico", "Malaysia", "Mozambique", "Namibia", "New Caledonia", "Niger", "Norfolk Island", "Nigeria", "Nicaragua", "Netherlands", "Norway", "Nepal", "Nauru", "Niue", "New Zealand", "Oman", "Panama", "Peru", "French Polynesia", "Papua New Guinea", "Philippines", "Pakistan", "Poland", "Saint Pierre and Miquelon", "Pitcairn Islands", "Puerto Rico", "Palestinian Territory", "Portugal", "Palau", "Paraguay", "Qatar", "Reunion", "Romania", "Russian Federation", "Rwanda", "Saudi Arabia", "Solomon Islands", "Seychelles", "Sudan", "Sweden", "Singapore", "Saint Helena", "Slovenia", "Svalbard and Jan Mayen", "Slovakia", "Sierra Leone", "San Marino", "Senegal", "Somalia", "Suriname", "Sao Tome and Principe", "El Salvador", "Syrian Arab Republic", "Swaziland", "Turks and Caicos Islands", "Chad", "French Southern Territories", "Togo", "Thailand", "Tajikistan", "Tokelau", "Turkmenistan", "Tunisia", "Tonga", "Timor-Leste", "Turkey", "Trinidad and Tobago", "Tuvalu", "Taiwan", "Tanzania, United Republic of", "Ukraine", "Uganda", "United States Minor Outlying Islands", "United States", "Uruguay", "Uzbekistan", "Holy See (Vatican City State)", "Saint Vincent and the Grenadines", "Venezuela", "Virgin Islands, British", "Virgin Islands, U.S.", "Vietnam", "Vanuatu", "Wallis and Futuna", "Samoa", "Yemen", "Mayotte", "Serbia", "South Africa", "Zambia", "Montenegro", "Zimbabwe", "Anonymous Proxy", "Satellite Provider", "Other", "Aland Islands", "Guernsey", "Isle of Man", "Jersey", "Saint Barthelemy", "Saint Martin");

our %country_map = (
    "" => "",
    A1 => "Anonymous Proxy",
    A2 => "Satellite Provider",
    AD => "Andorra",
    AE => "United Arab Emirates",
    AF => "Afghanistan",
    AG => "Antigua and Barbuda",
    AI => "Anguilla",
    AL => "Albania",
    AM => "Armenia",
    AN => "Netherlands Antilles",
    AO => "Angola",
    AP => "Asia/Pacific Region",
    AQ => "Antarctica",
    AR => "Argentina",
    AS => "American Samoa",
    AT => "Austria",
    AU => "Australia",
    AW => "Aruba",
    AX => "Aland Islands",
    AZ => "Azerbaijan",
    BA => "Bosnia and Herzegovina",
    BB => "Barbados",
    BD => "Bangladesh",
    BE => "Belgium",
    BF => "Burkina Faso",
    BG => "Bulgaria",
    BH => "Bahrain",
    BI => "Burundi",
    BJ => "Benin",
    BL => "Saint Barthelemy",
    BM => "Bermuda",
    BN => "Brunei Darussalam",
    BO => "Bolivia",
    BR => "Brazil",
    BS => "Bahamas",
    BT => "Bhutan",
    BV => "Bouvet Island",
    BW => "Botswana",
    BY => "Belarus",
    BZ => "Belize",
    CA => "Canada",
    CC => "Cocos (Keeling) Islands",
    CD => "Congo, The Democratic Republic of the",
    CF => "Central African Republic",
    CG => "Congo",
    CH => "Switzerland",
    CI => "Cote D\"Ivoire",
    CK => "Cook Islands",
    CL => "Chile",
    CM => "Cameroon",
    CN => "China",
    CO => "Colombia",
    CR => "Costa Rica",
    CU => "Cuba",
    CV => "Cape Verde",
    CX => "Christmas Island",
    CY => "Cyprus",
    CZ => "Czech Republic",
    DE => "Germany",
    DJ => "Djibouti",
    DK => "Denmark",
    DM => "Dominica",
    DO => "Dominican Republic",
    DZ => "Algeria",
    EC => "Ecuador",
    EE => "Estonia",
    EG => "Egypt",
    EH => "Western Sahara",
    ER => "Eritrea",
    ES => "Spain",
    ET => "Ethiopia",
    EU => "Europe",
    FI => "Finland",
    FJ => "Fiji",
    FK => "Falkland Islands (Malvinas)",
    FM => "Micronesia, Federated States of",
    FO => "Faroe Islands",
    FR => "France",
    FX => "France, Metropolitan",
    GA => "Gabon",
    GB => "United Kingdom",
    GD => "Grenada",
    GE => "Georgia",
    GF => "French Guiana",
    GG => "Guernsey",
    GH => "Ghana",
    GI => "Gibraltar",
    GL => "Greenland",
    GM => "Gambia",
    GN => "Guinea",
    GP => "Guadeloupe",
    GQ => "Equatorial Guinea",
    GR => "Greece",
    GS => "South Georgia and the South Sandwich Islands",
    GT => "Guatemala",
    GU => "Guam",
    GW => "Guinea-Bissau",
    GY => "Guyana",
    HK => "Hong Kong",
    HM => "Heard Island and McDonald Islands",
    HN => "Honduras",
    HR => "Croatia",
    HT => "Haiti",
    HU => "Hungary",
    ID => "Indonesia",
    IE => "Ireland",
    IL => "Israel",
    IM => "Isle of Man",
    IN => "India",
    IO => "British Indian Ocean Territory",
    IQ => "Iraq",
    IR => "Iran, Islamic Republic of",
    IS => "Iceland",
    IT => "Italy",
    JE => "Jersey",
    JM => "Jamaica",
    JO => "Jordan",
    JP => "Japan",
    KE => "Kenya",
    KG => "Kyrgyzstan",
    KH => "Cambodia",
    KI => "Kiribati",
    KM => "Comoros",
    KN => "Saint Kitts and Nevis",
    KP => "Korea, Democratic People\"s Republic of",
    KR => "Korea, Republic of",
    KW => "Kuwait",
    KY => "Cayman Islands",
    KZ => "Kazakhstan",
    LA => "Lao People\"s Democratic Republic",
    LB => "Lebanon",
    LC => "Saint Lucia",
    LI => "Liechtenstein",
    LK => "Sri Lanka",
    LR => "Liberia",
    LS => "Lesotho",
    LT => "Lithuania",
    LU => "Luxembourg",
    LV => "Latvia",
    LY => "Libyan Arab Jamahiriya",
    MA => "Morocco",
    MC => "Monaco",
    MD => "Moldova, Republic of",
    ME => "Montenegro",
    MF => "Saint Martin",
    MG => "Madagascar",
    MH => "Marshall Islands",
    MK => "Macedonia",
    ML => "Mali",
    MM => "Myanmar",
    MN => "Mongolia",
    MO => "Macau",
    MP => "Northern Mariana Islands",
    MQ => "Martinique",
    MR => "Mauritania",
    MS => "Montserrat",
    MT => "Malta",
    MU => "Mauritius",
    MV => "Maldives",
    MW => "Malawi",
    MX => "Mexico",
    MY => "Malaysia",
    MZ => "Mozambique",
    NA => "Namibia",
    NC => "New Caledonia",
    NE => "Niger",
    NF => "Norfolk Island",
    NG => "Nigeria",
    NI => "Nicaragua",
    NL => "Netherlands",
    NO => "Norway",
    NP => "Nepal",
    NR => "Nauru",
    NU => "Niue",
    NZ => "New Zealand",
    O1 => "Other",
    OM => "Oman",
    PA => "Panama",
    PE => "Peru",
    PF => "French Polynesia",
    PG => "Papua New Guinea",
    PH => "Philippines",
    PK => "Pakistan",
    PL => "Poland",
    PM => "Saint Pierre and Miquelon",
    PN => "Pitcairn Islands",
    PR => "Puerto Rico",
    PS => "Palestinian Territory",
    PT => "Portugal",
    PW => "Palau",
    PY => "Paraguay",
    QA => "Qatar",
    RE => "Reunion",
    RO => "Romania",
    RS => "Serbia",
    RU => "Russian Federation",
    RW => "Rwanda",
    SA => "Saudi Arabia",
    SB => "Solomon Islands",
    SC => "Seychelles",
    SD => "Sudan",
    SE => "Sweden",
    SG => "Singapore",
    SH => "Saint Helena",
    SI => "Slovenia",
    SJ => "Svalbard and Jan Mayen",
    SK => "Slovakia",
    SL => "Sierra Leone",
    SM => "San Marino",
    SN => "Senegal",
    SO => "Somalia",
    SR => "Suriname",
    ST => "Sao Tome and Principe",
    SV => "El Salvador",
    SY => "Syrian Arab Republic",
    SZ => "Swaziland",
    TC => "Turks and Caicos Islands",
    TD => "Chad",
    TF => "French Southern Territories",
    TG => "Togo",
    TH => "Thailand",
    TJ => "Tajikistan",
    TK => "Tokelau",
    TL => "Timor-Leste",
    TM => "Turkmenistan",
    TN => "Tunisia",
    TO => "Tonga",
    TR => "Turkey",
    TT => "Trinidad and Tobago",
    TV => "Tuvalu",
    TW => "Taiwan",
    TZ => "Tanzania, United Republic of",
    UA => "Ukraine",
    UG => "Uganda",
    UM => "United States Minor Outlying Islands",
    US => "United States",
    UY => "Uruguay",
    UZ => "Uzbekistan",
    VA => "Holy See (Vatican City State)",
    VC => "Saint Vincent and the Grenadines",
    VE => "Venezuela",
    VG => "Virgin Islands, British",
    VI => "Virgin Islands, U.S.",
    VN => "Vietnam",
    VU => "Vanuatu",
    WF => "Wallis and Futuna",
    WS => "Samoa",
    YE => "Yemen",
    YT => "Mayotte",
    ZA => "South Africa",
    ZM => "Zambia",
    ZW => "Zimbabwe",
);

sub new {
    my ($class, $file) = @_;
    open my $fh, "<", $file or die "Can't open '$file': $!\n";
    binmode $fh;
    my $self = bless {fh => $fh, file => $file}, $class;
    $self->segment();
    return $self;
}

sub segment {
    my ($self) = @_;
    $self->{type} = $GEOIP_COUNTRY_EDITION;
    $self->{reclen} = $STANDARD_RECORD_LENGTH;
    $self->{segments} = $GEOIP_COUNTRY_BEGIN;
    seek($self->{fh}, -3, 2);
    for my $i (0 .. $STRUCTURE_INFO_MAX_SIZE - 1) {
        my $retval = read($self->{fh}, my $delim, 3);
        if (!defined $retval) {
            die "Invalid database '$self->{file}'\n";
        }
        if ($delim ne "\xff\xff\xff") {
            seek($self->{fh}, -4 , 1);
            next;
        }
        read($self->{fh}, my $type, 1);
        $type = ord($type);
        $self->set_type($type);
        last;
    }
}

sub set_type {
    my ($self, $type) = @_;
    $type -= 105 if $type >= 106;
    $self->{type} = $type;
    if ($type == $GEOIP_REGION_EDITION_REV0) {
        $self->{segments} = $GEOIP_STATE_BEGIN_REV0;
    }
    elsif ($type == $GEOIP_REGION_EDITION_REV1) {
        $self->{segments} = $GEOIP_STATE_BEGIN_REV1;
    }
    elsif ($type == $GEOIP_CITY_EDITION_REV0 ||
           $type == $GEOIP_CITY_EDITION_REV1 ||
           $type == $GEOIP_ORG_EDITION ||
           $type == $GEOIP_ASNUM_EDITION ||
           $type == $GEOIP_DOMAIN_EDITION ||
           $type == $GEOIP_ISP_EDITION) {
        $self->{segments} = 0;
        read($self->{fh}, my $buf, $SEGMENT_RECORD_LENGTH);
        for my $j (0 .. $SEGMENT_RECORD_LENGTH - 1) {
            my $chr = substr($buf, $j, 1);
            my $n = ord($chr) << ($j * 8);
            $self->{segments} += $n;
        }
        if ($type == $GEOIP_ORG_EDITION ||
            $type == $GEOIP_ISP_EDITION ||
            $type == $GEOIP_DOMAIN_EDITION) {
            $self->{reclen} = $ORG_RECORD_LENGTH;
        }
    }
}

sub country {
    my ($self, $addr) = @_;
    my $index = $self->country_index($addr);
    my $country = $countries[$index];
    return $country;
}

sub country_name {
    my ($self, $addr) = @_;
    my $index = $self->country_index($addr);
    my $country_name = $country_names[$index];
    return $country_name;
}

sub city {
    my ($self, $addr) = @_;
    my $offset2 = $self->offset2($addr);
    seek($self->{fh}, $offset2, 0);
    read($self->{fh}, my $buf, $FULL_RECORD_LENGTH);
    my @a = unpack "C Z* Z* Z* a3 a3 a3", $buf;
    my ($i, $region, $city, $zip, $lat, $lon, $ad) = @a;
    $lat = unpack "L", "$lat\0";
    $lon = unpack "L", "$lon\0";
    $ad = unpack "L", "$ad\0";
    $lat = $lat / 10000 - 180;
    $lon = $lon / 10000 - 180;
    my $area = $ad % 1000;
    my $dma = int $ad / 1000;
    Encode::from_to($city, "iso-8859-1", "utf-8");
    my %h = (
        country => $countries[$i], country_name => $country_names[$i],
        region => $region, city => $city, zip => $zip,
        latitude => $lat, longitude => $lon, area => $area, dma => $dma,
    );
    return \%h;
}

sub isp {
    my ($self, $addr) = @_;
    my $offset2 = $self->offset2($addr);
    seek($self->{fh}, $offset2, 0);
    read($self->{fh}, my $buf, $MAX_ORG_RECORD_LENGTH);
    my $isp = unpack "Z*", $buf;
    Encode::from_to($isp, "iso-8859-15", "utf-8");
    return $isp;
}

sub country_index {
    my ($self, $addr) = @_;
    my $index = $self->offset1($addr) - $GEOIP_COUNTRY_BEGIN;
    return $index;
}

sub offset2 {
    my ($self, $addr) = @_;
    my $offset2 = $self->offset1($addr);
    $offset2 += (2 * $self->{reclen} - 1) * $self->{segments};
    return $offset2;
}

sub offset1 {
    my ($self, $addr) = @_;
    my $ip = addr_to_ip($addr);
    my $offset = 0;
    for my $i (reverse 0 .. 31) {
        seek($self->{fh}, $offset * 2 * $self->{reclen}, 0);
        read($self->{fh}, my $x, $self->{reclen});
        read($self->{fh}, my $y, $self->{reclen});
        $x = unpack("L", "$x\0");
        $y = unpack("L", "$y\0");
        if ($ip & (1 << $i)) {
            if ($y >= $self->{segments}) {
                $self->{mask} = 32 - $i;
                return $y;
            }
            $offset = $y;
        }
        else {
            if ($x >= $self->{segments}) {
                $self->{mask} = 32 - $i;
                return $x;
            }
            $offset = $x;
        }
    }
    die "Can't find $addr.";
}

sub addr_to_ip {
    my ($addr) = @_;
    if ($addr =~ /^\d+\.\d+\.\d+\.\d+$/) {
        my @parts = split /\./, $addr;
        my $ip = unpack "N", pack "C4", @parts;
        return $ip;
    }
    else {
        my $ip = unpack "N", (gethostbyname($addr))[4];
        return $ip;
    }
}

sub info {
    my ($self) = @_;
    my $has_struct;
    seek($self->{fh}, -3, 2);
    for my $i (0 .. $STRUCTURE_INFO_MAX_SIZE - 1) {
        read($self->{fh}, my $delim, 3);
        if ($delim ne "\xff\xff\xff") {
            seek($self->{fh}, -4 , 1);
            next;
        }
        $has_struct = 1;
        last;
    }
    if ($has_struct) {
        seek($self->{fh}, -6, 1);
    }
    else {
        seek($self->{fh}, -3, 2);
    }
    for my $i (0 .. $DATABASE_INFO_MAX_SIZE - 1) {
        read($self->{fh}, my $delim, 3);
        if ($delim ne "\x00\x00\x00") {
            seek($self->{fh}, -4, 1);
            next;
        }
        read($self->{fh}, my $info, $i);
        return $info;
    }
    return "";
}

1;


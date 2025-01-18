#!/usr/bin/env bash

# Shell script to check IP country code from various sources
# curl and jq are required to run this script

# Currently supported sources:
#   https://rdap.db.ripe.net
#   https://ipinfo.io
#   https://ipregistry.co
#   https://ipapi.com
#   https://db-ip.com
#   https://ipdata.co
#   https://ipwhois.io
#   https://ifconfig.co
#   https://whoer.net
#   https://ipquery.io
#   https://country.is
#   https://cleantalk.org
#   https://ip-api.com
#   https://ipgeolocation.io
#   https://ipapi.co
#   https://findip.net
#   https://geojs.io
#   https://iplocation.com
#   https://geoapify.com
#   https://ipapi.is
#   https://freeipapi.com
#   https://ipbase.com
#   https://ip.sb
#   https://maxmind.com

DEPENDENCIES="jq curl"

RIPE_DOMAIN="rdap.db.ripe.net"
IPINFO_DOMAIN="ipinfo.io"
IPREGISTRY_DOMAIN="ipregistry.co"
IPAPI_DOMAIN="ipapi.com"
DB_IP_DOMAIN="db-ip.com"
IPDATA_DOMAIN="ipdata.co"
IPWHOIS_DOMAIN="ipwhois.io"
IFCONFIG_DOMAIN="ifconfig.co"
WHOER_DOMAIN="whoer.net"
IPQUERY_DOMAIN="ipquery.io"
COUNTRY_IS_DOMAIN="country.is"
CLEANTALK_DOMAIN="cleantalk.org"
IP_API_DOMAIN="ip-api.com"
IPGEOLOCATION_DOMAIN="ipgeolocation.io"
IPAPI_CO_DOMAIN="ipapi.co"
FINDIP_DOMAIN="findip.net"
GEOJS_DOMAIN="geojs.io"
IPLOCATION_DOMAIN="iplocation.com"
GEOAPIFY_DOMAIN="geoapify.com"
IPAPI_IS_DOMAIN="ipapi.is"
FREEIPAPI_DOMAIN="freeipapi.com"
IPBASE_DOMAIN="ipbase.com"
IP_SB_DOMAIN="ip.sb"
MAXMIND_COM_DOMAIN="maxmind.com"

IDENTITY_SERVICES="https://ident.me https://ifconfig.co https://ifconfig.me https://icanhazip.com https://api64.ipify.org"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"

COLOR_RESET="\033[0m"
COLOR_BOLD_GREEN="\033[1;32m"
COLOR_BOLD_CYAN="\033[1;36m"

clear_screen() {
  clear
}

get_timestamp() {
  local format="$1"
  date +"$format"
}

log_message() {
  local log_level="$1"
  local message="${*:2}"
  local timestamp
  timestamp=$(get_timestamp "%d.%m.%Y %H:%M:%S")
  echo "[$timestamp] [$log_level]: $message"
}

is_installed() {
  command -v "$1" >/dev/null 2>&1
}

install_dependencies() {
  local use_sudo=""
  local missing_packages=()

  if [ "$(id -u)" -ne 0 ]; then
    use_sudo="sudo"
  fi

  for pkg in $DEPENDENCIES; do
    if ! is_installed "$pkg"; then
      missing_packages+=("$pkg")
    fi
  done

  if [ ${#missing_packages[@]} -eq 0 ]; then
    return 0
  fi

  log_message "INFO" "Missing dependencies: ${missing_packages[*]}. Do you want to install them?"
  select option in "Yes" "No"; do
    case "$option" in
      "Yes")
        log_message "INFO" "Installing missing dependencies"
        break
        ;;
      "No")
        log_message "INFO" "Exiting script"
        exit 0
        ;;
    esac
  done </dev/tty

  if [ -f /etc/os-release ]; then
    . /etc/os-release

    case "$ID" in
      debian | ubuntu)
        $use_sudo apt update
        NEEDRESTART_MODE=a $use_sudo apt install -y "${missing_packages[@]}"
        ;;
      arch)
        $use_sudo pacman -Syy --noconfirm "${missing_packages[@]}"
        ;;
      fedora)
        $use_sudo dnf install -y "${missing_packages[@]}"
        ;;
      *)
        log_message "ERROR" "Unknown or unsupported distribution: $ID"
        exit 1
        ;;
    esac

    clear_screen
  else
    log_message "ERROR" "File /etc/os-release not found, unable to determine distribution"
    exit 1
  fi
}

get_random_identity_service() {
  printf "%s" "$IDENTITY_SERVICES" | tr ' ' '\n' | shuf -n 1
}

get_ipv4() {
  external_ip=$(curl -4 -qs "$(get_random_identity_service)" 2>/dev/null)
  hidden_ip="$(printf "%s" "$external_ip" | cut -d'.' -f1-2).***.***"
}

check_service() {
  local domain="$1"
  local lookup_function="$2"
  printf "\r\033[KChecking: %s" "[$domain]"
  result="$($lookup_function)"
  results+=("[$COLOR_BOLD_GREEN$domain$COLOR_RESET]${COLOR_RESET}: $result")
}

print_results() {
  printf "%bResults for IP %b%s%b\n\n" "${COLOR_BOLD_GREEN}" "${COLOR_BOLD_CYAN}" "$hidden_ip" "${COLOR_RESET}"
  for result in "${results[@]}"; do
    printf "%b\n" "$result"
  done
}

ripe_rdap_lookup() {
  curl -s https://rdap.db.ripe.net/ip/"$external_ip" | jq -r ".country"
}

ipinfo_io_lookup() {
  curl -s https://ipinfo.io/widget/demo/"$external_ip" | jq -r ".data.country"
}

ipregistry_co_lookup() {
  # TODO: Add automatic API key parsing
  api_key="sb69ksjcajfs4c"
  curl -s "https://api.ipregistry.co/$external_ip?hostname=true&key=$api_key" -H "Origin: https://ipregistry.co" | jq -r ".location.country.code"
}

ipapi_com_lookup() {
  curl -s "https://ipapi.com/ip_api.php?ip=$external_ip" | jq -r ".country_code"
}

db_ip_com_lookup() {
  curl -s "https://db-ip.com/demo/home.php?s=$external_ip" | jq -r ".demoInfo.countryCode"
}

ipdata_co_lookup() {
  html=$(curl -s "https://ipdata.co")
  api_key=$(printf "%s" "$html" | grep -oP '(?<=api-key=)[a-zA-Z0-9]+')
  curl -s -H "Referer: https://ipdata.co" "https://api.ipdata.co/?api-key=$api_key" | jq -r ".country_code"
}

ipwhois_io_lookup() {
  curl -s -H "Referer: https://ipwhois.io" "https://ipwhois.io/widget?ip=$external_ip&lang=en" | jq -r ".country_code"
}

ifconfig_co_lookup() {
  curl -s "https://ifconfig.co/country-iso?ip=$external_ip"
}

whoer_net_lookup() {
  curl -s "https://whoer.net/whois?host=$external_ip" | grep "country" | awk 'NR==1 {print $2}'
}

ipquery_io_lookup() {
  curl -s "https://api.ipquery.io/$external_ip" | jq -r ".location.country_code"
}

country_is_lookup() {
  curl -s "https://api.country.is/$external_ip" | jq -r ".country"
}

cleantalk_org_lookup() {
  curl -s "https://api.cleantalk.org/?method_name=ip_info&ip=$external_ip" | jq -r --arg ip "$external_ip" '.data[$ip | tostring].country_code'
}

ip_api_com_lookup() {
  curl -s "https://demo.ip-api.com/json/$external_ip" -H "Origin: https://ip-api.com" | jq -r ".countryCode"
}

ipgeolocation_io_lookup() {
  curl -s "https://api.ipgeolocation.io/ipgeo?ip=$external_ip" -H "Referer: https://ipgeolocation.io" | jq -r ".country_code2"
}

ipapi_co_lookup() {
  curl -s "https://ipapi.co/$external_ip/json" | jq -r ".country"
}

findip_net_lookup() {
  cookie_file=$(mktemp)
  html=$(curl -s -c "$cookie_file" "https://findip.net")
  request_verification_token=$(printf "%s" "$html" | grep "__RequestVerificationToken" | grep -oP 'value="\K[^"]+')
  response=$(curl -s -X POST "https://findip.net" \
    --data-urlencode "__RequestVerificationToken=$request_verification_token" \
    --data-urlencode "ip=$external_ip" \
    -b "$cookie_file")
  rm "$cookie_file"
  printf "%s" "$response" | grep -oP 'ISO Code: <span class="text-success">\K[^<]+'
}

geojs_io_lookup() {
  curl -s "https://get.geojs.io/v1/ip/country.json?ip=$external_ip" | jq -r ".[0].country"
}

iplocation_com_lookup() {
  curl -s -X POST "https://iplocation.com" -A "$USER_AGENT" --form "ip=$external_ip" | jq -r ".country_code"
}

geoapify_com_lookup() {
  # TODO: Add automatic API key parsing
  api_key="b8568cb9afc64fad861a69edbddb2658"
  curl -s "https://api.geoapify.com/v1/ipinfo?&ip=$external_ip&apiKey=$api_key" | jq -r ".country.iso_code"
}

ipapi_is_lookup() {
  curl -s "https://api.ipapi.is/?q=$external_ip" | jq -r ".location.country_code"
}

freeipapi_com_lookup() {
  curl -s "https://freeipapi.com/api/json/$external_ip" | jq -r ".countryCode"
}

ipbase_com_lookup() {
  curl -s "https://api.ipbase.com/v2/info?ip=$external_ip" | jq -r ".data.location.country.alpha2"
}

ip_sb_lookup() {
  curl -s "https://api.ip.sb/geoip/$external_ip" -A "$USER_AGENT" | jq -r ".country_code"
}

maxmind_com_lookup() {
  curl -s "https://geoip.maxmind.com/geoip/v2.1/city/me" -H "Referer: https://www.maxmind.com" | jq -r ".country.iso_code"
}

main() {
  install_dependencies

  declare -a results

  get_ipv4

  check_service "$RIPE_DOMAIN" ripe_rdap_lookup
  check_service "$IPINFO_DOMAIN" ipinfo_io_lookup
  check_service "$IPREGISTRY_DOMAIN" ipregistry_co_lookup
  check_service "$IPAPI_DOMAIN" ipapi_com_lookup
  check_service "$DB_IP_DOMAIN" db_ip_com_lookup
  check_service "$IPDATA_DOMAIN" ipdata_co_lookup
  check_service "$IPWHOIS_DOMAIN" ipwhois_io_lookup
  check_service "$IFCONFIG_DOMAIN" ifconfig_co_lookup
  check_service "$WHOER_DOMAIN" whoer_net_lookup
  check_service "$IPQUERY_DOMAIN" ipquery_io_lookup
  check_service "$COUNTRY_IS_DOMAIN" country_is_lookup
  check_service "$CLEANTALK_DOMAIN" cleantalk_org_lookup
  check_service "$IP_API_DOMAIN" ip_api_com_lookup
  # NOTE: Disabled due to captcha
  # check_service "$IPGEOLOCATION_DOMAIN" ipgeolocation_io_lookup
  check_service "$IPAPI_CO_DOMAIN" ipapi_co_lookup
  # NOTE: Disabled due to captcha
  # check_service "$FINDIP_DOMAIN" findip_net_lookup
  check_service "$GEOJS_DOMAIN" geojs_io_lookup
  check_service "$IPLOCATION_DOMAIN" iplocation_com_lookup
  check_service "$GEOAPIFY_DOMAIN" geoapify_com_lookup
  check_service "$IPAPI_IS_DOMAIN" ipapi_is_lookup
  check_service "$FREEIPAPI_DOMAIN" freeipapi_com_lookup
  check_service "$IPBASE_DOMAIN" ipbase_com_lookup
  check_service "$IP_SB_DOMAIN" ip_sb_lookup
  check_service "$MAXMIND_COM_DOMAIN" maxmind_com_lookup

  clear_screen

  print_results
}

main

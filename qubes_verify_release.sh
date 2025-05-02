#!/usr/bin/env bash
# -------------------------------------------------------------
# Script di verifica Qubes OS Release
# Basato sulle direttive di Qubes OS: https://www.qubes-os.org/security/verifying-signatures/
#
# Usage examples:
#   Interactive mode:
#     ./qubes_verify_release.sh \
#       -f Qubes-R4.1.0-x86_64.iso \
#       -s Qubes-R4.1.0-x86_64.iso.asc \
#       -v 4.1.0
#
#   Non-interactive (CI/CD):
#     ./qubes_verify_release.sh \
#       -f Qubes-R4.1.0-x86_64.iso \
#       -s Qubes-R4.1.0-x86_64.iso.asc \
#       -v 4.1.0 \
#       -n
#
#   Specificando RSK locale:
#     ./qubes_verify_release.sh \
#       -f Qubes-R4.1.0-x86_64.iso \
#       -s Qubes-R4.1.0-x86_64.iso.asc \
#       -k /path/to/qubes-release-4.1-signing-key.asc
#
# Options:
#   -f, --file PATH        File di rilascio da verificare (obbligatorio)
#   -s, --sig PATH         File di firma corrispondente (obbligatorio)
#   -v, --version X.Y      Versione Qubes (per recupero RSK)
#   -k, --rsk-key PATH|URL File RSK locale o URL
#   -n, --non-interactive  Modalità non interattiva (fiducia automatica)
#   -h, --help             Mostra questo help
# -------------------------------------------------------------

set -euo pipefail

# Costanti QMSK
readonly QMSK_FPR="427F11FD0FAA4B080123F01CDDFA1A3E36879494"
readonly QMSK_ID="0x427F11FD0FAA4B080123F01CDDFA1A3E36879494"
readonly QMSK_URL="https://keys.qubes-os.org/keys/qubes-master-signing-key.asc"

# Colori
readonly RED="\e[31m"
readonly GREEN="\e[32m"
readonly YELLOW="\e[33m"
readonly BOLD="\e[1m"
readonly RESET="\e[0m"

usage() {
  cat <<EOF
${BOLD}Usage:${RESET} $0 [options]

Opzioni:
  -f, --file PATH        File di rilascio da verificare
  -s, --sig PATH         File di firma corrispondente
  -v, --version X.Y      Versione Qubes (per recupero RSK)
  -k, --rsk-key PATH|URL File RSK locale o URL
  -n, --non-interactive  Modalità non interattiva
  -h, --help             Mostra questo help
EOF
  exit 1
}

# Parametri
FILE="" SIG="" VERSION="" RSK="" NON_INTERACTIVE=false

# Parse opzioni
while [[ $# -gt 0 ]]; do
  case $1 in
  -f | --file)
    FILE="$2"
    shift 2
    ;;
  -s | --sig)
    SIG="$2"
    shift 2
    ;;
  -v | --version)
    VERSION="$2"
    shift 2
    ;;
  -k | --rsk-key)
    RSK="$2"
    shift 2
    ;;
  -n | --non-interactive)
    NON_INTERACTIVE=true
    shift
    ;;
  -h | --help) usage ;;
  *)
    echo -e "${RED}Errore:${RESET} Opzione sconosciuta '$1'" >&2
    usage
    ;;
  esac
done

# Verifica parametri obbligatori
[[ -z "$FILE" || -z "$SIG" ]] && usage

# Controllo file leggibili
for p in "$FILE" "$SIG"; do
  if [[ ! -r "$p" ]]; then
    echo -e "${RED}Errore:${RESET} File non leggibile: $p" >&2
    exit 2
  fi
done

# Funzione per importare chiave via URL
import_key_url() {
  local url="$1"
  echo -e "Importo chiave da URL: $url"
  gpg2 --fetch-keys "$url"
}

# 1) Importa e autentica QMSK
if ! gpg2 --list-keys "$QMSK_ID" &>/dev/null; then
  echo -e "${YELLOW}QMSK non presente, importo...${RESET}"
  import_key_url "$QMSK_URL"
else
  echo -e "${GREEN}QMSK già presente${RESET}"
fi

# Verifica fingerprint QMSK
FP_ACTUAL=$(gpg2 --with-colons --fingerprint "$QMSK_ID" | awk -F: '/^fpr/ {print $10; exit}')
if [[ "${FP_ACTUAL,,}" != "${QMSK_FPR,,}" ]]; then
  echo -e "${RED}Errore:${RESET} fingerprint QMSK non corrisponde!" >&2
  exit 3
fi

echo -e "Fingerprint QMSK verificato: $FP_ACTUAL"

# Imposta trust ultimate
echo -e "Imposto trust ultimate per QMSK..."
if ! $NON_INTERACTIVE; then
  gpg2 --command-fd 0 --edit-key "$QMSK_ID" trust quit <<EOF
5
y
EOF
else
  echo -e "${YELLOW}Non-interactive: trust impostato automaticamente${RESET}"
  gpg2 --batch --yes --edit-key "$QMSK_ID" trust quit <<EOF
5
y
EOF
fi

# 2) Importa RSK
if [[ -z "$RSK" ]]; then
  if [[ -n "$VERSION" ]]; then
    RSK="https://keys.qubes-os.org/keys/qubes-release-${VERSION}-signing-key.asc"
  else
    echo -e "${RED}Errore:${RESET} specifica RSK con -k o versione con -v" >&2
    exit 1
  fi
fi

echo -e "Importo RSK da: $RSK"
if [[ "$RSK" =~ ^https?:// ]]; then
  import_key_url "$RSK"
else
  gpg2 --import "$RSK"
fi

echo -e "RSK importata con successo"

# 3) Verifica firma del rilascio
echo -e "Verifico firma: $SIG su $FILE"
gpg2 --verify "$SIG" "$FILE"

if [[ $? -eq 0 ]]; then
  echo -e "${GREEN}✓ Firma valida!${RESET}"
  exit 0
else
  echo -e "${RED}✗ Firma non valida!${RESET}" >&2
  exit 4
fi

#!/usr/bin/env bash
# Upload tokenbar 0.1.1. Create a token at https://pypi.org/manage/account/token/
# then:
#   export TWINE_USERNAME=__token__
#   export TWINE_PASSWORD=pypi-AgEIcHlwaS5vcmc...
#   ./scripts/publish_pypi_0_1_1.sh
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/verify_cli_parity.py
python3 -m twine check dist/tokenbar-0.1.1*
python3 -m twine upload dist/tokenbar-0.1.1-py3-none-any.whl dist/tokenbar-0.1.1.tar.gz
echo "Verify: pip index versions tokenbar && pip install -U tokenbar && tokenbar --version"

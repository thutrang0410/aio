**if command -v pkg >/dev/null; then pkg install -y wget; else apk add wget; fi && wget -qO- raw.githubusercontent.com/thutrang0410/aio/main/vietbot-aio.sh | sh**
**if command -v pkg >/dev/null 2>&1; then
    pkg install -y wget
elif command -v apk >/dev/null 2>&1; then
    apk update && apk add wget
elif command -v brew >/dev/null 2>&1; then
    brew install wget
fi && wget -qO- https://raw.githubusercontent.com/thutrang0410/aio/main/vietbot-aio.sh | sh**

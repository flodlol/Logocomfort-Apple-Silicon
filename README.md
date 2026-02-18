# LOGO! Soft Comfort for M‑series Macs

This makes the Intel macOS version run on Apple silicon (Rosetta + Intel Java), so it doesn't instantly close.

## Disclaimer

I don't own LOGO! Soft Comfort and I'm not affiliated with Siemens. This repo doesn't include their software. It only patches the launcher. LOGO! / LOGO! Soft Comfort are Siemens trademarks.

## Downloads

1) [LOGO! Soft Comfort v8.4 Demo (Siemens)](https://support.industry.siemens.com/cs/document/109826921/logo!soft-comfort-v8-4-demo?dti=0&lc=en-GB)  
2) [Java 11+ (Azul Zulu)](https://www.azul.com/core-post-download/?endpoint=zulu&uuid=f6d9f03c-44f3-49d0-976f-e11561997a32) (pick **macOS x64 / Intel**, download the `.pkg`)

## Install

1) Download + unzip the Siemens demo (you'll get `lsc_v8_4_demo`)
2) Install Java (double-click the `.pkg`, click through)
3) Install LOGOComfort using Siemens' installer (`Setup.zip` is here):
   - `lsc_v8_4_demo/Web_Installers/InstData/MacOSX/NoVM/Setup.zip`

![Correct Folder](docs/screenshots/screenshot-1.png)

Important:
- Don’t move only `LOGOComfort.app` somewhere else: it must stay next to `lib/` + `bin/` (JavaFX/serial native libs live there).

## Patch (step-by-step)

### Step 1 — Install Rosetta (Apple‑silicon only)

If you have an M‑series Mac, run this once (it’s safe to run again).
If you’re on an Intel Mac, skip this step.

```bash
sudo softwareupdate --install-rosetta --agree-to-license
```

### Step 2 — Install Intel (x86_64) Java 11+

You need **Intel (x86_64) Java 11+** on Apple‑silicon (ARM Java won’t work for this app).

After installing Java, this should list at least one `x86_64` Java:

```bash
/usr/libexec/java_home -V --arch x86_64
```

### Step 3 — Download this repo

Option A (with git):

```bash
cd ~/Downloads
git clone https://github.com/flodlol/Logocomfort-Apple-Silicon.git
cd Logocomfort-Apple-Silicon
```

Option B (no git):

```bash
cd ~/Downloads
curl -fL "https://github.com/flodlol/Logocomfort-Apple-Silicon/archive/refs/heads/main.zip" -o Logocomfort-Apple-Silicon.zip
ditto -xk Logocomfort-Apple-Silicon.zip .
cd Logocomfort-Apple-Silicon-main
```

### Step 4 — Run the quick fix

This patches the launcher and then opens LOGOComfort.
If it asks for your password, that’s `sudo` (needed when the app is installed somewhere protected).

```bash
bash scripts/quickfix.sh
```

If it can’t find your app automatically, pass the app path (tip: drag `LOGOComfort.app` into Terminal to insert the path):

```bash
bash scripts/quickfix.sh "/path/to/LOGOComfort.app"
```

### Step 5 — If it still fails

Check the log:

```bash
tail -n 200 /tmp/LOGOComfort-launch.log
```

Or run the doctor script (same “drag the app into Terminal” trick works here too):

```bash
bash scripts/doctor.sh "/path/to/LOGOComfort.app"
```

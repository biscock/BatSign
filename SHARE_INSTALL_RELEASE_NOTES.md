Fixes sharing IPA files directly into BatSign: **Share → BatSign → import → sign → install**.

### Changes
- Copy incoming IPA/TIPA files into app-owned storage before asynchronous import.
- Retain security-scoped access until copying finishes and coordinate file-provider reads.
- Handle file URLs at the root view, show import progress, and present import errors after launch.
- Queue shared packages for immediate signing and installation, without the pending-sign tray.
- Correct document settings and register the standard IPA document type.

### Installation
Sign `BatSign.ipa` with your own certificate and install it. Do not enable KSign's **File Sharing** modification when signing BatSign. Add your `.p12` and `.mobileprovision` in BatSign, then share another IPA to the app. iOS may still ask for installation confirmation.

### Validation
The maintainer confirmed that this build works on their iPhone. The asset is the exact IPA from [successful build #1](https://github.com/biscock/BatSign/actions/runs/38147013958), built from commit `61bc199aacc666a8639c19f26a233cf616f815ef`; it has not been rebuilt for this release. The app's internal version remains 0.0.4.

SHA-256 (`BatSign.ipa`): `53eb2ea575b20884983ab35b0970184f83827e65510924f52b40e25d46b0f402`.

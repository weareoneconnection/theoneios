# TheOne for iOS

The native iPhone and iPad client for TheOne. It is deliberately isolated from
the production web and Electron repositories:

- `theone-complete` remains the web/API authority.
- `theone-desktop` remains the local-computer runtime.
- `theone-ios` is an independently built, signed and released client.

The first native foundation uses SwiftUI for launch, sign-in, network state and
device integration. The authenticated product surface uses the existing secure
web session, so the mobile client cannot fork tenant, authority or execution
semantics from the server. No shell, downloaded code or local OneClaw runtime is
executed on iOS.

## Build

1. Open `TheOne.xcodeproj` in Xcode.
2. Select an iPhone simulator and run the `TheOne` scheme.
3. For a device/archive, set the OneAI Labs Apple Development Team and register
   bundle identifier `ai.oneailabs.theone`.

Command-line verification:

```sh
./scripts/verify.sh
```

## Authentication

Apple login uses the system-provided control, a nonce-bound identity token that
the server verifies against Apple's public keys, and the same single-use
PKCE-bound handoff used by GitHub. The verifier stays in the app. Email login
remains available in the first-party TheOne sign-in surface. Set
`THEONE_APPLE_CLIENT_ID=ai.oneailabs.theone` on the API deployment before a
signed TestFlight build is tested.

The authenticated surface receives a narrow, origin-checked native bridge for
the iOS share sheet, haptics and complete device sign-out. It does not expose a
filesystem, shell, arbitrary URL opener or privileged execution API.

## Separation contract

The iOS project never imports source or build output from the web or desktop
repositories. Integration happens only through versioned HTTPS contracts and
the `theone://auth` callback. A broken mobile build therefore cannot alter a web
or desktop deployment.

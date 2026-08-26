# ProspectProfit

BUY/SKIP prospecting EV for TBC ores from live Auction House prices.

Open the **Prospect** tab at the AH. The addon scans ore and gem listings, estimates expected gem value, and tells you whether a 20-stack is worth buying.

## Install

1. Copy the `ProspectProfit` folder into `World of Warcraft/_classic_tbc_/Interface/AddOns/`
   (TBC Anniversary / `Interface: 20506`).
2. Restart the client and enable **ProspectProfit**.
3. At the Auction House, open the Prospect tab. Bind Previous/Next ore to bumpers if you want pad-friendly ore cycling.

## Use

- `/prospect` or `/prospectprofit` toggles the window.
- `/prospect scan` shows the window and scans the selected ore.
- `/prospect next` / `/prospect prev` cycle ores.

TBC Classic Anniversary.

## CurseForge packaging

Releases are built by [CurseForge automatic packaging](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging) from this repo.

1. Create the project on CurseForge if it does not exist yet.
2. Generate an API token at [curseforge.com/account/api-tokens](https://www.curseforge.com/account/api-tokens).
3. In GitHub: **Settings → Webhooks → Add webhook**.
   - Payload URL: `https://www.curseforge.com/api/projects/{projectID}/package?token={token}`
   - Content type: `application/json`
   - Events: **Just the `push` event**
4. Publish by pushing a git tag:
   - `1.0.1` → release
   - `1.0.1-beta` → beta
   - `1.0.1-alpha` → alpha

`{projectID}` is the numeric ID in **About This Project** on the CurseForge overview. Untagged commits package as alpha only if the project is set to package every commit.

The packaged zip uses `@project-version@` from the tag (see `.pkgmeta`).

## License

[MIT](LICENSE)

/**
 * Finicky — která aplikace otevírá odkazy v jakém prohlížeči.
 * Docs: https://github.com/johnste/finicky/wiki/Configuration-(v4)
 *
 * Work and personal are two Brave builds now: work = stable Brave, personal =
 * Brave Beta. Two applications instead of two profiles inside one app, because
 * activating an app raises all of its windows in every Space — with both profiles
 * in stable Brave, focusing work dragged the personal window over the terminal on
 * the other display.
 *
 * Work does not use `profile` on purpose. Finicky implements `profile` as
 * `open -n --args --profile-directory=…`, and with that flag Chromium opens a
 * NEW window whenever the last active Brave window is an app-mode/PWA window
 * (ClickUp, Home Assistant, Positive Intelligence …): an app window cannot host
 * a normal tab, so Chromium creates one. The "Brave Work Opener" applet raises
 * an existing normal Brave window first and only then asks Chromium for the
 * Work profile, so a window is created only when there is none to reuse.
 * (The applet itself lives in ~/Applications and hardcodes `Profile 1`.)
 *
 * Typecheck: the exported types ship with the app (`.d.ts` inside the bundle).
 * Config changes are picked up automatically on save.
 */
import type {
  BrowserSpecification,
  FinickyConfig,
  UrlMatcher,
} from "/Applications/Finicky.app/Contents/Resources/finicky";

/** Work lives in stable Brave, in the "Work" profile (see the applet above). */
const WORK: BrowserSpecification = {
  name: "/Users/matejbransky/Applications/Brave Work Opener.app",
  appType: "path",
};

/** Personal lives in Brave Beta, which has a single profile. */
const PERSONAL: BrowserSpecification = {
  name: "com.brave.Browser.beta",
  appType: "bundleId",
};

/**
 * Apps whose links belong to work. Matched by bundle id, including its
 * helpers (`<id>.helper`, `<id>.modulehost`, …) via prefix.
 */
const WORK_APP_BUNDLE_IDS = [
  "com.tinyspeck.slackmacgap", // Slack
  "com.microsoft.Outlook", // Microsoft Outlook
  "com.microsoft.teams2", // Microsoft Teams (new)
  "com.microsoft.teams", // Microsoft Teams (classic)
  "com.todesktop.230313mzl4w4u92", // Cursor
  "com.anthropic.claudefordesktop", // Claude desktop
  "com.brave.Browser.app.edcmabgkbicempmpgmniellhbjopafjh", // ClickUp (Brave PWA)
  "com.figma.Desktop", // Figma desktop app
  "com.figma.universalLinks", // Figma universal-links helper
] as const;

const isWorkApp: UrlMatcher = (_url, { opener }) => {
  const bundleId = opener?.bundleId ?? "";
  return WORK_APP_BUNDLE_IDS.some(
    (id) => bundleId === id || bundleId.startsWith(`${id}.`),
  );
};

/**
 * Slack channels whose links belong to the personal browser instead.
 *
 * Slack names its windows like `jokes (Channel) - Xplor - Slack`, so the
 * channel is matched from `opener.windowTitle` (Finicky 4.4+, requires
 * Accessibility permission). Channel names are used as regex, so escape
 * anything special (`.`, `+`, `(` …).
 */
const PERSONAL_SLACK_CHANNELS = ["jokes"] as const;

const personalSlackChannelPattern = new RegExp(
  `^(${PERSONAL_SLACK_CHANNELS.join("|")}) \\((?:Channel|DM|Group DM)\\)`,
  "i",
);

const isPersonalSlackChannel: UrlMatcher = (_url, { opener }) =>
  opener?.bundleId === "com.tinyspeck.slackmacgap" &&
  personalSlackChannelPattern.test(opener.windowTitle ?? "");

export default {
  // Everything not matched by a handler below opens in the personal browser.
  defaultBrowser: PERSONAL,

  options: {
    checkForUpdates: true,
    // Flip to false once you are happy — the log records every visited URL.
    logRequests: true,
    keepRunning: true,
    hideIcon: false,
  },

  handlers: [
    {
      // Links clicked in the Slack channels above go to the personal browser,
      // so this must be listed before the generic work rule below.
      match: isPersonalSlackChannel,
      browser: PERSONAL,
    },
    {
      match: isWorkApp,
      browser: WORK,
    },
    {
      // URLs opened from a terminal or CLI (Claude Code, `open`, scripts, …)
      // arrive with no opener at all, so the source app cannot be detected.
      // Those are development/work URLs, so they go to the work browser.
      match: (_url, { opener }) => !opener?.bundleId,
      browser: WORK,
    },
  ],
} satisfies FinickyConfig;

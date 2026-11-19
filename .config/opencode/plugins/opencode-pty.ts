import { Plugin } from "opencode-pty/v2"

export default {
  ...Plugin,
  setup: (context: Parameters<typeof Plugin.setup>[0]) =>
    Plugin.setup({
      ...context,
      options: {
        ...context.options,
        port: 4200,
        hostname: "127.0.0.1",
        autostart: false,
      },
    }),
}

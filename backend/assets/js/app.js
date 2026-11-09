import {Socket} from "phoenix";
import {LiveSocket} from "phoenix_live_view";

const KeepOpen = {
  mounted() { this.wasOpen = this.el.open; },
  beforeUpdate() { this.wasOpen = this.el.open; },
  updated() { this.el.open = this.wasOpen; }
};

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken}, hooks: {KeepOpen}
});
liveSocket.connect();
window.addEventListener("phx:focus-editor", () => {
  document.getElementById("invoice-form")?.scrollIntoView({behavior: "smooth", block: "start"});
});

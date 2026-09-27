// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { render } from "preact";

import Connection from "../connection";
import App from "./App";

// Chrome calls its light theme "default", Firefox calls it "light".
document.documentElement.dataset.theme =
  chrome.devtools.panels.themeName === "dark" ? "dark" : "light";

render(<App connection={new Connection()} />, document.getElementById("app")!);

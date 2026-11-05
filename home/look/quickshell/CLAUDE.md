# Quickshell bar

## After any bar change: idle check

Once a bar change is deployed (switch done, bar restarted), check that it stops drawing when
nothing changes:

    home/look/quickshell/dev/idle-check.sh          # read-only, ~10 s, hands off the laptop
    home/look/quickshell/dev/idle-check.sh --animations   # if that fails: which animation runs

Ask the user to keep hands off (the cursor moving fails the check), and run it in the background.
`--animations` pauses the real bar and shows a copy for ~15 s; say so first. Report the numbers;
don't call a bar change done while the check fails.

Why: an infinite animation keeps running while its item sits in a hidden popup, and Qt advances
it through the visible bar's render loop. The bar then sends Hyprland 60 identical frames a
second (~5% CPU each, on a fanless laptop) with nothing visibly moving. Found twice in Nov 2026:
the Syncthing spinner stuck on offline peers, and the Wi-Fi connect-step pulse while connected.

## Writing animations

- Gate every `loops: Animation.Infinite` on a condition that is false whenever it cannot be
  seen: include the popup/row's visibility (e.g. `running: open && svc.connecting`), not only
  the state it shows. A state like "step == current" stays true after the flow ends.
- Hidden popups shouldn't keep live content: a `Behavior` on data that updates by itself
  animates in a closed popup too (System Stats' core bars on the 1 s sample: ~20 frames/s).
  Put popup bodies in `Loader { active: panel.visible }`, as Wifi.qml and SystemStats.qml do.
  When `--animations` is clean but the check fails, bisect by switching off one service timer
  per copy: the one whose removal drops the frames feeds the animating item.

## Finding short bursts (qmlprofiler)

When the idle check fails but `--animations` is clean, profile a copy (prepared as below) started
with `quickshell -p <copy> --debug 3768`, then:

    { sleep 12; echo r; sleep 4; echo o; sleep 4; echo q; sleep 1; echo y; } |
        qmlprofiler --interactive -a 127.0.0.1 -p 3768 -o prof.qtd

(`qmlprofiler` is in `qt6.qtdeclarative`; without the `o` it discards the data.) In the .qtd,
`AnimationFrame` events per second give the frame rate, and the most frequent
`Javascript`/`Binding` events (file:line) show what runs per frame or per poll.

## Test copies

Running a copy of the bar (`quickshell -p <copy>`): neutralise GlowService's hyprsunset and
brightnessctl calls first (a second instance resets the screen colour), pause the real bar
instead of running both, and delete the copy's `~/.local/state/quickshell/by-shell/<id>`
afterwards. `dev/idle-check.sh --animations` does all of this.

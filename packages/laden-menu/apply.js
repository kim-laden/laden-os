// Replace the first Kickoff in each panel with the Laden menu + dashboard, keep position.
var done = 0;
panels().forEach(function (p) {
    if (done) return;
    var ws = p.widgets(), old = null;
    for (var i = 0; i < ws.length; i++) if (ws[i].type == "org.kde.plasma.kickoff" || ws[i].type == "org.kde.plasma.kicker") { old = ws[i]; break; }
    if (!old) return;
    var order = p.widgetIds.slice();
    var at = order.indexOf(old.id);
    var k = p.addWidget("org.kde.plasma.kickoff"); ladenSetupKickoff(k);
    var d = p.addWidget("org.kde.plasma.kickerdash"); ladenSetupDashboard(d);
    old.remove();
    order.splice(at, 1, k.id, d.id);
    p.currentConfigGroup = ["General"];
    p.writeConfig("AppletOrder", order.join(";"));
    print("panel " + p.id + ": kickoff " + k.id + ", dashboard " + d.id + "\nLADEN_ORDER " + p.id + " " + order.join(";"));
    done = 1;
});
if (!done) {
    // no launcher found: add both to the first panel
    var p0 = panels()[0];
    if (p0) { var k2 = p0.addWidget("org.kde.plasma.kickoff"); ladenSetupKickoff(k2);
              var d2 = p0.addWidget("org.kde.plasma.kickerdash"); ladenSetupDashboard(d2); print("added to panel " + p0.id); }
}

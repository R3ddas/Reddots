// Recursos: https://www.youtube.com/watch?v=leCzeCeNxas

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts                  // Para usar RowLayout o ColumnLayout

NotificationServer{
    id:server
    actionsSupported: true
    bodySupported: true
}
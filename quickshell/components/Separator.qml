// Línea horizontal de 1 px con el color de los bordes del tema: entre las partes de un
// desplegable o bajo un título de sección (SectionTitle.qml). Va dentro de un layout y
// ocupa todo el ancho; el aire de encima y de debajo lo pone quien lo usa (Layout.topMargin...).
import QtQuick
import QtQuick.Layouts
import qs.services

Rectangle {
    Layout.fillWidth: true
    implicitHeight: 1
    color: Theme.border
}

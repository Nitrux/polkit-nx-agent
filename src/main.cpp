// SPDX-License-Identifier: BSD-3-Clause
// Copyright 2026 Nitrux Latinoamericana S.C. <hello@nxos.org>

#include <QCoreApplication>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSurfaceFormat>
#include <QUrl>
#include <KLocalizedContext>
#include <KLocalizedString>
#include <MauiKit4/Core/mauiapp.h>
#include "polkitagent.h"
int main(int argc, char *argv[]) {
    QSurfaceFormat format; format.setAlphaBufferSize(8); QSurfaceFormat::setDefaultFormat(format);
    QGuiApplication app(argc, argv);
    app.setOrganizationName(QStringLiteral("Maui"));
    app.setApplicationName(QStringLiteral("polkit-nx-agent"));
    KLocalizedString::setApplicationDomain(QByteArrayLiteral("polkit-nx-agent"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("dialog-password")));
    MauiApp::instance()->setIconName(QStringLiteral("dialog-password"));
    PolkitAgent agent; if (!agent.registerForCurrentSession()) return 1;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
    engine.rootContext()->setContextProperty(QStringLiteral("agent"), &agent);
    const QUrl url(QStringLiteral("qrc:/app/maui/polkitnxagent/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
        [url](QObject *object, const QUrl &objectUrl) {
            if (!object && url == objectUrl) QCoreApplication::exit(1);
        }, Qt::QueuedConnection);
    engine.load(url);
    return engine.rootObjects().isEmpty() ? 1 : app.exec();
}

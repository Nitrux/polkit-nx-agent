#include "polkitagent.h"

#include <QDebug>
#include <QFileInfo>
#include <QImageReader>
#include <QRegularExpression>
#include <QSettings>
#include <pwd.h>
#include <unistd.h>

namespace {
QString labelFor(const QString &raw)
{
    if (!raw.startsWith(QStringLiteral("unix-user:")))
        return raw;
    const QString value = raw.mid(10);
    bool ok = false;
    const uid_t uid = value.toUInt(&ok);
    if (!ok)
    {
        const QByteArray usernameData = value.toLocal8Bit();
        const struct passwd *entry = getpwnam(usernameData.constData());
        if (!entry || !entry->pw_name)
            return value;

        const QString username = QString::fromLocal8Bit(entry->pw_name);
        QSettings account(QStringLiteral("/var/lib/AccountsService/users/") + username,
                          QSettings::IniFormat);
        const QString accountName = account.value(QStringLiteral("User/RealName")).toString().trimmed();
        if (!accountName.isEmpty())
            return accountName;

        const QString realName = QString::fromLocal8Bit(entry->pw_gecos).section(QStringLiteral(","), 0, 0).trimmed();
        return realName.isEmpty() ? username : realName;
    }
    struct passwd entry {};
    struct passwd *result = nullptr;
    char buffer[4096] {};
    if (getpwuid_r(uid, &entry, buffer, sizeof(buffer), &result) == 0 &&
        result && result->pw_name) {
        const QString username = QString::fromLocal8Bit(result->pw_name);
        QSettings account(QStringLiteral("/var/lib/AccountsService/users/") + username,
                          QSettings::IniFormat);
        const QString accountName = account.value(QStringLiteral("User/RealName")).toString().trimmed();
        if (!accountName.isEmpty())
            return accountName;

        const QString realName = QString::fromLocal8Bit(result->pw_gecos).section(QStringLiteral(","), 0, 0).trimmed();
        return realName.isEmpty() ? username : realName;
    }
    return value;
}

QString detail(const PolkitQt1::Details &details, const QString &key)
{
    return details.keys().contains(key) ? details.lookup(key) : QString();
}

QString avatarPathForIdentity(const QString &identity)
{
    if (!identity.startsWith(QStringLiteral("unix-user:")))
        return {};

    bool ok = false;
    const uid_t uid = identity.mid(10).toUInt(&ok);
    struct passwd entry {};
    struct passwd *result = nullptr;
    char buffer[4096] {};
    QString username;
    QString home;
    if (ok) {
        if (getpwuid_r(uid, &entry, buffer, sizeof(buffer), &result) != 0 ||
            !result || !result->pw_name || !result->pw_dir)
            return {};
        username = QString::fromLocal8Bit(result->pw_name);
        home = QString::fromLocal8Bit(result->pw_dir);
    } else {
        const QByteArray usernameData = identity.mid(10).toLocal8Bit();
        const struct passwd *namedEntry = getpwnam(usernameData.constData());
        if (!namedEntry || !namedEntry->pw_name || !namedEntry->pw_dir)
            return {};
        username = QString::fromLocal8Bit(namedEntry->pw_name);
        home = QString::fromLocal8Bit(namedEntry->pw_dir);
    }

    const QStringList candidates{
        home + QStringLiteral("/.face"),
        home + QStringLiteral("/.face.icon"),
        QStringLiteral("/var/lib/AccountsService/icons/") + username,
    };

    for (const QString &candidate : candidates) {
        const QFileInfo info(candidate);
        if (!info.isFile() || !info.isReadable())
            continue;

        QImageReader reader(candidate);
        reader.setDecideFormatFromContent(true);
        if (reader.canRead())
            return candidate;
    }

    return {};
}
}

PolkitAgent::PolkitAgent(QObject *parent)
    : PolkitQt1::Agent::Listener(parent)
{
}

PolkitAgent::~PolkitAgent()
{
    if (m_session) {
        m_session->disconnect(this);
        m_session->cancel();
        delete m_session;
    }
    if (m_result) {
        m_result->setCompleted();
        delete m_result;
    }
}

bool PolkitAgent::registerForCurrentSession()
{
    const QString session = qEnvironmentVariable("XDG_SESSION_ID");
    if (session.isEmpty()) {
        qWarning() << "polkit-nx-agent: XDG_SESSION_ID is not set";
        return false;
    }
    const PolkitQt1::UnixSessionSubject subject(session);
    const bool registered = registerListener(
        subject, QStringLiteral("/org/maui/PolicyKit1/AuthenticationAgent"));
    if (!registered)
        qWarning() << "polkit-nx-agent: failed to register the authentication agent";
    return registered;
}

#define GETTER(name, type, member) type PolkitAgent::name() const { return member; }
GETTER(active, bool, m_active)
GETTER(actionId, QString, m_actionId)
GETTER(message, QString, m_message)
GETTER(iconName, QString, m_iconName)
GETTER(identities, QVariantList, m_identityData)
GETTER(selectedIdentity, int, m_selectedIdentity)
GETTER(details, QVariantList, m_detailData)
GETTER(vendor, QString, m_vendor)
GETTER(vendorUrl, QString, m_vendorUrl)
GETTER(command, QString, m_command)
GETTER(prompt, QString, m_prompt)
GETTER(echo, bool, m_echo)
GETTER(info, QString, m_info)
GETTER(error, QString, m_error)
#undef GETTER

QUrl PolkitAgent::avatarUrl() const
{
    if (m_selectedIdentity < 0 || m_selectedIdentity >= m_identities.size())
        return QUrl(QStringLiteral("qrc:/app/maui/polkitnxagent/icons/user-avatar.svg"));

    const QString path = avatarPathForIdentity(m_identities.at(m_selectedIdentity).toString());
    return path.isEmpty()
        ? QUrl(QStringLiteral("qrc:/app/maui/polkitnxagent/icons/user-avatar.svg"))
        : QUrl::fromLocalFile(path);
}

void PolkitAgent::initiateAuthentication(const QString &actionId, const QString &message,
    const QString &iconName, const PolkitQt1::Details &details, const QString &cookie,
    const PolkitQt1::Identity::List &identities, PolkitQt1::Agent::AsyncResult *result)
{
    if (m_session) {
        m_session->disconnect(this);
        m_session->cancel();
        m_session->deleteLater();
        m_session = nullptr;
    }
    if (m_result) {
        m_result->setError(QStringLiteral("Another authentication request is active"));
        m_result->setCompleted();
        delete m_result;
    }

    m_result = result;
    m_cookie = cookie;
    m_actionId = actionId;
    m_message = message;
    m_iconName = iconName;
    m_identities = identities;
    m_identityData.clear();
    m_detailData.clear();
    m_vendor = detail(details, QStringLiteral("polkit.vendor"));
    m_vendorUrl = detail(details, QStringLiteral("polkit.vendor_url"));
    m_command = detail(details, QStringLiteral("command_line"));
    if (m_command.isEmpty()) m_command = detail(details, QStringLiteral("cmdline"));
    if (m_command.isEmpty()) m_command = detail(details, QStringLiteral("command"));
    if (m_command.isEmpty()) {
        static const QRegularExpression quotedCommand(
            QStringLiteral("[`'\\\"\\x{201c}\\x{201d}\\x{2018}\\x{2019}]([^`'\\\"\\x{201c}\\x{201d}\\x{2018}\\x{2019}]+)[`'\\\"\\x{201c}\\x{201d}\\x{2018}\\x{2019}]"));
        const QRegularExpressionMatch match = quotedCommand.match(m_message);
        if (match.hasMatch())
            m_command = match.captured(1);
    }
    if (m_command.isEmpty()) {
        static const QRegularExpression pathCommand(QStringLiteral("(/[A-Za-z0-9_./+:-]+)"));
        const QRegularExpressionMatch match = pathCommand.match(m_message);
        if (match.hasMatch())
            m_command = match.captured(1);
    }

    for (const auto &identity : m_identities) {
        const QString raw = identity.toString();
        m_identityData.append(QVariantMap{{QStringLiteral("id"), raw},
                                          {QStringLiteral("label"), labelFor(raw)}});
    }
    m_detailData.append(QVariantMap{{QStringLiteral("key"), QStringLiteral("Action")},
                                      {QStringLiteral("value"), actionId}});
    for (const QString &key : details.keys()) {
        if (key.startsWith(QStringLiteral("polkit.")) ||
            key == QStringLiteral("command_line") || key == QStringLiteral("cmdline") ||
            key == QStringLiteral("command"))
            continue;
        if (details.lookup(key).isEmpty())
            continue;
        m_detailData.append(QVariantMap{{QStringLiteral("key"), key},
                                        {QStringLiteral("value"), details.lookup(key)}});
    }

    m_selectedIdentity = 0;
    const QString preferred = QStringLiteral("unix-user:%1").arg(getuid());
    for (int i = 0; i < m_identities.size(); ++i) {
        if (m_identities.at(i).toString() == preferred) {
            m_selectedIdentity = i;
            break;
        }
    }
    Q_EMIT selectedIdentityChanged();
    Q_EMIT avatarChanged();

    m_cancelRequested = false;
    m_restarting = false;
    setPrompt(QString(), false);
    setInfo(QString());
    setError(QString());
    setActive(true);
    Q_EMIT requestChanged();
    createSession();
}

void PolkitAgent::createSession()
{
    if (!m_result || m_selectedIdentity < 0 ||
        m_selectedIdentity >= m_identities.size()) {
        setError(QStringLiteral("No valid identity was provided by Polkit"));
        finish(true);
        return;
    }

    m_session = new PolkitQt1::Agent::Session(
        m_identities.at(m_selectedIdentity), m_cookie, m_result, this);
    connect(m_session, &PolkitQt1::Agent::Session::request,
            this, &PolkitAgent::setPrompt);
    connect(m_session, &PolkitQt1::Agent::Session::showInfo,
            this, &PolkitAgent::setInfo);
    connect(m_session, &PolkitQt1::Agent::Session::showError,
            this, &PolkitAgent::setError);
    connect(m_session, &PolkitQt1::Agent::Session::completed,
            this, &PolkitAgent::sessionCompleted);
    m_session->initiate();
}

void PolkitAgent::sessionCompleted(bool gained)
{
    auto *session = m_session;
    m_session = nullptr;
    if (session)
        session->deleteLater();

    if (m_restarting) {
        m_restarting = false;
        setPrompt(QString(), false);
        setInfo(QString());
        setError(QString());
        createSession();
    } else if (gained || m_cancelRequested) {
        finish(false);
    } else {
        if (m_error.isEmpty())
            setError(QStringLiteral("Authentication failed. Please try again."));
        setPrompt(QString(), false);
        createSession();
    }
}

void PolkitAgent::submitResponse(const QString &response)
{
    if (m_session && !response.isEmpty())
        m_session->setResponse(response);
}

void PolkitAgent::cancel()
{
    cancelAuthentication();
}

void PolkitAgent::cancelAuthentication()
{
    if (!m_result)
        return;
    m_cancelRequested = true;
    if (m_session)
        m_session->cancel();
    else
        finish(false);
}

void PolkitAgent::selectIdentity(int index)
{
    if (!m_active || index < 0 || index >= m_identities.size() ||
        index == m_selectedIdentity)
        return;

    m_selectedIdentity = index;
    Q_EMIT selectedIdentityChanged();
    Q_EMIT avatarChanged();
    m_restarting = true;
    setPrompt(QString(), false);
    setInfo(QString());
    setError(QString());

    if (m_session)
        m_session->cancel();
    else
        createSession();
}

bool PolkitAgent::initiateAuthenticationFinish()
{
    return true;
}

void PolkitAgent::finish(bool failed)
{
    if (m_session) {
        m_session->disconnect(this);
        m_session->cancel();
        m_session->deleteLater();
        m_session = nullptr;
    }
    if (!m_result)
        return;
    if (failed)
        m_result->setError(QStringLiteral("Authentication failed"));
    m_result->setCompleted();
    delete m_result;
    m_result = nullptr;

    m_cookie.clear();
    setPrompt(QString(), false);
    setActive(false);
}

void PolkitAgent::setActive(bool active)
{
    if (m_active == active)
        return;
    m_active = active;
    Q_EMIT activeChanged();
}

void PolkitAgent::setPrompt(const QString &text, bool echo)
{
    QString prompt = text.trimmed();
    if (prompt.endsWith(QLatin1Char(':')))
        prompt.chop(1);
    prompt = prompt.trimmed();
    if (prompt.isEmpty() && !text.isEmpty())
        prompt = QStringLiteral("Password");
    if (m_prompt == prompt && m_echo == echo)
        return;
    m_prompt = prompt;
    m_echo = echo;
    Q_EMIT promptChanged();
}

void PolkitAgent::setInfo(const QString &text)
{
    if (m_info == text)
        return;
    m_info = text;
    Q_EMIT infoChanged();
}

void PolkitAgent::setError(const QString &text)
{
    if (m_error == text)
        return;
    m_error = text;
    Q_EMIT errorChanged();
}

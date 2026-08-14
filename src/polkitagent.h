#pragma once
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <PolkitQt1/Agent/Listener>
#include <PolkitQt1/Agent/Session>
#include <PolkitQt1/Details>
#include <PolkitQt1/Identity>
#include <PolkitQt1/Subject>

class PolkitAgent final : public PolkitQt1::Agent::Listener {
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(QString actionId READ actionId NOTIFY requestChanged)
    Q_PROPERTY(QString message READ message NOTIFY requestChanged)
    Q_PROPERTY(QString iconName READ iconName NOTIFY requestChanged)
    Q_PROPERTY(QVariantList identities READ identities NOTIFY requestChanged)
    Q_PROPERTY(int selectedIdentity READ selectedIdentity NOTIFY selectedIdentityChanged)
    Q_PROPERTY(QVariantList details READ details NOTIFY requestChanged)
    Q_PROPERTY(QString vendor READ vendor NOTIFY requestChanged)
    Q_PROPERTY(QString vendorUrl READ vendorUrl NOTIFY requestChanged)
    Q_PROPERTY(QString command READ command NOTIFY requestChanged)
    Q_PROPERTY(QString prompt READ prompt NOTIFY promptChanged)
    Q_PROPERTY(bool echo READ echo NOTIFY promptChanged)
    Q_PROPERTY(QString info READ info NOTIFY infoChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
public:
    explicit PolkitAgent(QObject *parent = nullptr);
    ~PolkitAgent() override;
    bool registerForCurrentSession();
    bool active() const; QString actionId() const; QString message() const;
    QString iconName() const; QVariantList identities() const;
    int selectedIdentity() const; QVariantList details() const;
    QString vendor() const; QString vendorUrl() const; QString command() const;
    QString prompt() const; bool echo() const; QString info() const; QString error() const;
    Q_INVOKABLE void submitResponse(const QString &response);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void selectIdentity(int index);
public Q_SLOTS:
    void initiateAuthentication(const QString &, const QString &, const QString &,
        const PolkitQt1::Details &, const QString &, const PolkitQt1::Identity::List &,
        PolkitQt1::Agent::AsyncResult *) override;
    void cancelAuthentication() override;
    bool initiateAuthenticationFinish() override;
Q_SIGNALS:
    void activeChanged(); void requestChanged(); void selectedIdentityChanged();
    void promptChanged(); void infoChanged(); void errorChanged();
private:
    void createSession(); void finish(bool); void setActive(bool);
    void setPrompt(const QString &, bool); void setInfo(const QString &);
    void setError(const QString &); void sessionCompleted(bool);
    bool m_active = false;
    QString m_actionId, m_message, m_iconName, m_vendor, m_vendorUrl, m_command;
    QVariantList m_identityData, m_detailData;
    PolkitQt1::Identity::List m_identities;
    int m_selectedIdentity = -1;
    QString m_prompt, m_info, m_error, m_cookie;
    bool m_echo = false, m_cancelRequested = false, m_restarting = false;
    PolkitQt1::Agent::AsyncResult *m_result = nullptr;
    PolkitQt1::Agent::Session *m_session = nullptr;
};

#include "macosswiftcontroller.h"
#include "mozillavpn.h"
#include "keys.h"
#include "device.h"
#include "server.h"
#include "Mozilla_VPN-Swift.h"

#import <Cocoa/Cocoa.h>

#include <QDebug>
#include <QByteArray>

// Our Swift singleton.
static MacOSControllerImpl *impl = nullptr;

// static
void MacOSSwiftController::activate(const Server* server, std::function<void()> && a_failureCallback)
{
    qDebug() << "MacOSSWiftController - activate";

    Q_ASSERT(impl);

    std::function<void()> failureCallback = std::move(a_failureCallback);

    [impl connectWithServerIpv4Gateway:server->ipv4Gateway().toNSString()
                     serverIpv6Gateway:server->ipv6Gateway().toNSString()
                       serverPublicKey:server->publicKey().toNSString()
                      serverIpv4AddrIn:server->ipv4AddrIn().toNSString()
                            serverPort:server->choosePort()
                           ipv6Enabled:MozillaVPN::instance()->settingsHolder()->ipv6()
                       failureCallback:^() {
                           qDebug() << "MacOSSWiftController - connection failed";
                           failureCallback();
                       }];
}

// static
void MacOSSwiftController::deactivate()
{
    Q_ASSERT(impl);
    qDebug() << "MacOSSWiftController - deactivate";

    [impl disconnect];
}

// static
void MacOSSwiftController::initialize(const Device* device, const Keys* keys, std::function<void(bool, Controller::State, const QDateTime&)>&& a_callback, std::function<void(Controller::State)>&& a_stateChangeCallback)
{
    Q_ASSERT(!impl);

    std::function<void(bool, Controller::State, const QDateTime&)> callback = std::move(a_callback);
    std::function<void(Controller::State)> stateChangeCallback = std::move(a_stateChangeCallback);

    qDebug() << "Initializing Swift Controller";

    static bool creating = false;
    // No nested creation!
    Q_ASSERT(creating == false);
    creating = true;

    QByteArray key = QByteArray::fromBase64(keys->privateKey().toLocal8Bit());

    impl = [[MacOSControllerImpl alloc] initWithPrivateKey:key.toNSData()
                                               ipv4Address:device->ipv4Address().toNSString()
                                               ipv6Address:device->ipv6Address().toNSString()
                                               ipv6Enabled:MozillaVPN::instance()->settingsHolder()->ipv6()
                                                   closure:^(ConnectionState state, NSDate* date) {
        qDebug() << "Creation completed with connection state:" << state;
        creating = false;

        switch (state) {
            case ConnectionStateError: {
                [impl dealloc];
                impl = nullptr;
                callback(false, Controller::StateOff, QDateTime());
                return;
            }
            case ConnectionStateConnected: {
                Q_ASSERT(date);
                QDateTime qtDate(QDateTime::fromNSDate(date));
                callback(true, Controller::StateOn, qtDate);
                return;
            }
            case ConnectionStateDisconnected:
                callback(true, Controller::StateOff, QDateTime());
                return;
        }
    }
                                          callback:^(BOOL connected) {
        qDebug() << "State changed: " << connected;
        stateChangeCallback(connected ? Controller::StateOn : Controller::StateOff);
    }
            ];
}

void MacOSSwiftController::checkStatus(std::function<void ()> &&a_statusCallback) {
    std::function<void()> statusCallback = a_statusCallback;
// TODO
}

function eventFired(transaction, eventName) {
    for (var i = 0; i < transaction.logs.length; i++) {
        var log = transaction.logs[i];
        if (log.event == eventName) {
            // We found the event!
            assert.isTrue(true);
        }
        else {
            assert.isTrue(false, "Did not find " + eventName);
        }
    }
};
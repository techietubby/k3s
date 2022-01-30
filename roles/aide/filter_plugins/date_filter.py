import datetime

def date_filter(arg):
    value = datetime.datetime.utcfromtimestamp(arg).strftime('%Y-%m-%d')
    return value

class FilterModule(object):
    def filters(self):
        return { 'date_filter': date_filter }

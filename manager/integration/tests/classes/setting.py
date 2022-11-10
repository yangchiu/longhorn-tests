

class Setting:

    SETTING_AUTO_SALVAGE = "auto-salvage"

    def __init__(self, client):
        self.client = client

    def set_auto_salvage(self, value="false"):
        auto_salvage_setting = self.client.by_id_setting(Setting.SETTING_AUTO_SALVAGE)
        setting = self.client.update(auto_salvage_setting, value=value)
        assert setting.name == Setting.SETTING_AUTO_SALVAGE
        assert setting.value == value



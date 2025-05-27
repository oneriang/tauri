const I18N = {
    currentLang: 'ja', // 默认语言
    messages: {},

    init() {
        const savedLang = localStorage.getItem('lang') || this.currentLang;
        this.currentLang = savedLang;
        this.loadMessages(savedLang);
        this.translatePage();
    },

    async loadMessages(lang) {
        try {
            const res = await fetch(`/static/locales/${lang}.json`);
            this.messages = await res.json();
        } catch (err) {
            console.error("Failed to load language file:", err);
        }
    },

    translatePage() {
        document.querySelectorAll('[data-i18n]').forEach(el => {
            const key = el.getAttribute('data-i18n');
            if (this.messages[key]) {
                el.textContent = this.messages[key];
            }
        });
    },

    setLanguage(lang) {
        this.currentLang = lang;
        localStorage.setItem('lang', lang);
        this.loadMessages(lang).then(() => this.translatePage());
    }
};

document.addEventListener('DOMContentLoaded', () => {
    I18N.init();
});

(() => {
  "use strict";

  const $ = (id) => document.getElementById(id);
  const login = $("adminLogin");
  const loading = $("loading");
  const denied = $("denied");
  const dashboard = $("dashboard");
  let client = null;

  const countryNames = {
    BR:"Brasil", PT:"Portugal", US:"Estados Unidos", ES:"Espanha", FR:"França",
    DE:"Alemanha", IT:"Itália", GB:"Reino Unido", IE:"Irlanda", CA:"Canadá",
    JP:"Japão", AR:"Argentina", MX:"México", AO:"Angola", MZ:"Moçambique",
    CH:"Suíça", NL:"Países Baixos", BE:"Bélgica", LU:"Luxemburgo"
  };

  function flagEmoji(code) {
    if (!code || code === "--" || code.length !== 2) return "🌐";
    return [...code.toUpperCase()].map(c => String.fromCodePoint(127397 + c.charCodeAt())).join("");
  }
  function number(value) { return Number(value || 0).toLocaleString("pt-BR"); }
  function resetViews() {
    login.classList.add("hidden"); loading.classList.add("hidden");
    denied.classList.add("hidden"); dashboard.classList.add("hidden");
  }
  function showLogin(message="") {
    resetViews(); login.classList.remove("hidden");
    $("loginError").textContent = message;
    $("adminPassword").value = "";
  }
  function showDenied(message) {
    resetViews(); denied.classList.remove("hidden");
    if (message) denied.querySelector("p").textContent = message;
  }
  function renderCountries(items) {
    const box = $("countries"); box.innerHTML = "";
    if (!Array.isArray(items) || !items.length) {
      box.innerHTML = '<div class="empty">Ainda não há localização de acessos registrada.</div>'; return;
    }
    items.forEach(item => {
      const code = String(item.country_code || "--").toUpperCase();
      const row = document.createElement("div"); row.className = "country-row";
      const flag = document.createElement("span"); flag.className = "flag"; flag.textContent = flagEmoji(code);
      const name = document.createElement("span"); name.className = "country-name";
      name.textContent = countryNames[code] || (code === "--" ? "País não identificado" : code);
      const count = document.createElement("strong"); count.className = "country-count"; count.textContent = number(item.count);
      row.append(flag,name,count); box.appendChild(row);
    });
  }
  async function isAdmin(userId) {
    const { data, error } = await client.from("admins").select("user_id").eq("user_id", userId).maybeSingle();
    return !error && !!data;
  }
  async function loadDashboard(user) {
    resetViews(); loading.classList.remove("hidden");
    if (!(await isAdmin(user.id))) {
      await client.auth.signOut();
      showLogin("Conta sem autorização de administrador."); return;
    }
    const { data, error } = await client.rpc("admin_dashboard");
    if (error) {
      console.error("admin_dashboard:", error);
      showDenied("O painel administrativo ainda não está ativado no Supabase ou não foi possível carregar os dados."); return;
    }
    $("adminIdentity").textContent = user.email || "Administrador IL Chats Mail";
    $("supabaseStatus").textContent = "Conectado";
    $("sessionStatus").textContent = "Administrador autorizado";
    $("registered").textContent = number(data?.registered_accounts);
    $("active7d").textContent = number(data?.active_7d);
    $("messages").textContent = number(data?.messages_sent);
    $("visits").textContent = number(data?.visits);
    $("leads").textContent = number(data?.leads);
    $("customers").textContent = number(data?.customers);
    $("conversion").textContent = `${Number(data?.lead_conversion || 0).toLocaleString("pt-BR")} %`;
    renderCountries(data?.countries);
    $("lastUpdate").textContent = new Date().toLocaleString("pt-BR");
    resetViews(); dashboard.classList.remove("hidden");
  }

  async function start() {
    if (!window.supabase || !window.ILMAIL_SUPABASE_URL || !window.ILMAIL_SUPABASE_PUBLISHABLE_KEY) {
      showDenied("A configuração pública do Supabase não foi encontrada."); return;
    }
    client = window.supabase.createClient(window.ILMAIL_SUPABASE_URL, window.ILMAIL_SUPABASE_PUBLISHABLE_KEY);

    /* Login administrativo é sempre explícito: não abre o painel só porque o e-mail comum já tem sessão. */
    await client.auth.signOut();
    showLogin();

    $("adminLoginForm").addEventListener("submit", async (event) => {
      event.preventDefault();
      $("loginError").textContent = "";
      const email = $("adminEmail").value.trim();
      const password = $("adminPassword").value;
      const button = event.submitter;
      button.disabled = true; button.textContent = "Verificando…";
      try {
        const { data, error } = await client.auth.signInWithPassword({ email, password });
        if (error || !data?.user) { showLogin("E-mail ou senha inválidos."); return; }
        if (!(await isAdmin(data.user.id))) {
          await client.auth.signOut(); showLogin("Esta conta não possui autorização de administrador."); return;
        }
        await loadDashboard(data.user);
      } finally {
        button.disabled = false; button.textContent = "Entrar";
      }
    });

    $("refreshBtn").addEventListener("click", async () => {
      const { data:{ user } } = await client.auth.getUser();
      if (!user) { showLogin("A sessão administrativa terminou. Entre novamente."); return; }
      await loadDashboard(user);
    });
  }

  start().catch(err => { console.error(err); showDenied("Não foi possível abrir a Área do Administrador."); });
})();
# IL Chats Mail v5 — Mensagens funcionando com Supabase

Esta versão troca a simulação principal por uma caixa postal interna conectada ao Supabase.

## O que funciona nesta versão
- Login, criação de conta, confirmação de e-mail, recuperação de senha e logout via Supabase Auth.
- Envio de mensagens **entre usuários cadastrados e confirmados do IL Chats Mail**.
- Caixa de entrada e Enviados carregados do banco.
- Favoritos, lida/não lida, Lixeira, restaurar e excluir da própria caixa.
- Rascunhos persistidos no Supabase.
- Responder, responder a todos e encaminhar.
- Minha Marca/assinatura local por conta e por navegador.
- Painel administrativo opcional: contas cadastradas, contas ativas em 7 dias, mensagens, acessos autenticados e país/região aproximado pelo idioma do navegador.
- Layout responsivo para computador, tablet e celular.
- SEO, Open Graph, manifest, robots e sitemap.

## Antes de publicar
1. No projeto **IL Chats Mail** do Supabase, execute `setup-supabase.sql` no SQL Editor. Não execute no projeto IL Chats/Bate-papos IL.
2. Abra `supabase-config.js` e substitua `COLE_AQUI_SUA_PUBLISHABLE_KEY` pela Publishable/anon key pública do projeto IL Chats Mail.
3. Para habilitar sua Área do administrador, copie seu UUID em Authentication > Users e execute no SQL Editor:
   `insert into public.admins(user_id) values ('SEU-UUID-AQUI') on conflict do nothing;`
4. Publique os arquivos no repositório `IL-Chats-Mail`.

## Limite importante
Esta versão entrega **mensagens reais dentro do IL Chats Mail**, entre contas registradas no mesmo sistema. Ela ainda não é um servidor de e-mail da Internet: enviar/receber para Gmail, Outlook, Yahoo ou domínios externos exige integrar posteriormente um provedor de e-mail/SMTP/API e configurar SPF, DKIM e DMARC.

## Anexos
O seletor de anexos continua visível, mas o upload real para Supabase Storage ainda não foi ativado nesta versão. Isso deve ser a próxima etapa antes de anunciar fotos/vídeos/documentos como funcionalidade concluída.

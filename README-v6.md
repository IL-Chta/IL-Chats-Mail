# IL Chats Mail v6

Base v6 preparada para:
- autenticação Supabase;
- mensagens internas;
- envio externo para endereços válidos (Gmail, Outlook, Yahoo e outros) por Edge Function + Resend;
- estrutura para recebimento externo por webhook;
- painel administrativo com cadastrados, visitas, leads, clientes finalizados e conversão;
- estrutura de anexos.

## Antes de produção
1. Executar/revisar `setup-supabase.sql` somente no projeto IL Chats Mail.
2. Inserir a Publishable Key em `supabase-config.js`.
3. Criar/verificar o domínio no provedor de e-mail e configurar SPF/DKIM/MX/DMARC conforme instruções do provedor.
4. Salvar `RESEND_API_KEY` e `ILMAIL_FROM` como Supabase Edge Function Secrets. Nunca colocar chaves privadas no GitHub/frontend.
5. Deploy da função `send-external-email`.
6. Para recebimento, concluir validação criptográfica da assinatura do webhook e recuperar corpo/anexos pela Receiving API antes de deploy de produção. O arquivo inbound atual é deliberadamente um esqueleto e NÃO deve ser publicado como webhook aberto.
7. Criar bucket privado para anexos e política de Storage antes de ativar anexos reais.
8. Testar ponta a ponta com contas IL Chats Mail e destinatários Gmail/Outlook/Yahoo.

A v6 não altera o projeto IL Chats/Bate-papos IL.

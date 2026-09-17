# IL Chats Mail — ativação da versão recuperada v11

1. Faça backup do projeto Supabase IL Chats Mail.
2. Confirme que `setup-supabase.sql` e `supabase-migration-v7.sql` já correspondem ao schema atual. Não execute SQL às cegas em outro projeto.
3. No SQL Editor do projeto **IL Chats Mail**, execute `supabase-migration-v11.sql`.
4. Faça deploy das Edge Functions `recover-account` e `send-external-email`.
5. Configure os Secrets das Edge Functions no Supabase: `RESEND_API_KEY` e `ILMAIL_FROM` (não coloque os valores no GitHub). Os secrets internos do Supabase são fornecidos pelo ambiente.
6. Para envio externo, o domínio/remetente precisa estar verificado no Resend. Sem isso, o envio externo continuará limitado pelo provedor.
7. O webhook `inbound-email` NÃO deve ser publicado ainda: a cópia original não valida a assinatura do webhook nem recupera o corpo/anexos recebidos.
8. Teste primeiro: cadastro/login; perfil/foto; contato; calendário; nota; mensagem interna; rascunho; anexo; envio externo para um destinatário permitido pelo Resend.

## O que foi corrigido nesta cópia
- nome duplicado no avatar/cabeçalho;
- perfil com foto e fallback por iniciais;
- Contatos com criar/editar/excluir e botão para escrever;
- Calendário com criar/editar/excluir compromissos;
- Notas com criar/editar/excluir;
- limpeza correta dos anexos ao iniciar nova mensagem;
- tabelas/RLS e buckets necessários aos novos recursos.

## Limite ainda dependente de infraestrutura externa
Receber e-mail real da Internet requer domínio/MX e webhook de recebimento validado. Isso não pode ser concluído apenas com HTML/JavaScript no GitHub Pages.

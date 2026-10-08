// Correção: excluir rascunhos.
(()=>{
 if(document.getElementById('deleteDraftBtn'))return;
 let busy=false;
 const button=document.createElement('button');
 button.id='deleteDraftBtn';button.type='button';
 button.className='secondary danger hidden';
 button.textContent='Excluir rascunho';
 $('#composeDialog .compose-footer').prepend(button);

 async function erase(id){
  if(busy||!id||!sb||!currentUser)return;
  if(!confirm('Excluir definitivamente este rascunho?'))return;
  busy=true;button.disabled=true;
  const controls=[$('#saveDraftBtn'),$('#composeForm [type="submit"]')].filter(Boolean);
  const disabled=controls.map(b=>b.disabled);
  controls.forEach(b=>b.disabled=true);
  try{
   const {data,error}=await withTimeout(
    sb.from('drafts').delete()
     .eq('id',id).eq('user_id',currentUser.id)
     .select('id'),15000
   );
   if(error)throw error;
   if(!data?.some(row=>row.id===id))
    throw new Error('O banco não confirmou a exclusão.');
   if(currentDraftId===id){
    currentDraftId=null;
    $('#composeDialog').close();
    $('#composeForm').reset();
    selectedAttachments=[];
    renderAttachments();useBrand=false;
    $('#signaturePreview').classList.add('hidden');
    button.classList.add('hidden');
   }
   await loadMailbox();
   toast('Rascunho excluído');
  }catch(error){
   toast('Não foi possível excluir: '+error.message);
  }finally{
   busy=false;button.disabled=false;
   controls.forEach((b,i)=>b.disabled=disabled[i]);
  }
 }
 button.onclick=()=>erase(currentDraftId);

 const oldRender=renderList;
 renderList=function(){
  oldRender();
  if(currentFolder!=='drafts')return;
  const items=visibleMessages();
  $$('#messageList .message').forEach((row,i)=>{
   if(!items[i]?.isDraft)return;
   const remove=document.createElement('button');
   remove.type='button';remove.textContent='🗑';
   remove.title='Excluir rascunho';
   remove.setAttribute('aria-label','Excluir rascunho');
   remove.style.cssText='display:block;min-width:44px;min-height:44px';
   remove.onclick=e=>{
    e.stopPropagation();
    return erase(items[i].id);
   };
   row.lastElementChild.appendChild(remove);
  });
 };
 const oldOpen=openDraft;
 openDraft=function(m){
  oldOpen(m);button.classList.remove('hidden');
 };
 $('#composeBtn').addEventListener('click',()=>{
  button.classList.add('hidden');
 });
 if(currentFolder==='drafts')renderList();
})();

/* Human decisions are saved as wiki revisions. Generated builds are read-only here. */
mw.loader.using( [ 'vue', '@wikimedia/codex' ] ).then( function ( require ) {
 const { createApp, h, ref } = require( 'vue' );
 const { CdxTable, TableRowIdentifier } = require( '@wikimedia/codex' );
 'use strict';
 const root = document.getElementById( 'maw-dashboard' );
 if ( !root ) { return; }
 const api = new mw.Api();
 let status, build = '', view = 'records', offset = 0, serial = 0, listSerial = 0;
 const el = ( tag, text, attrs = {} ) => {
  const node = document.createElement( tag );
  if ( text !== null ) { node.textContent = text; }
  for ( const [ key, value ] of Object.entries( attrs ) ) { node.setAttribute( key, value ); }
  return node;
 };
 const button = ( label, fn ) => {
  const node = el( 'button', label, { type: 'button', class: 'cdx-button' } );
  node.addEventListener( 'click', fn ); return node;
 };
 const message = el( 'p', '', { role: 'status', 'aria-live': 'polite' } );
 const controls = el( 'div', null, { class: 'maw-controls' } );
 const buildSelect = el( 'select', null, { 'aria-label': 'Source build' } );
 const query = el( 'input', null, { type: 'search', placeholder: 'Find a record by name', 'aria-label': 'Find records' } );
 const reviewFilter = el( 'select', null, { 'aria-label': 'Issue state' } );
 [ [ 'attention', 'Needs attention' ], [ 'all', 'All history' ], [ 'open', 'Open' ], [ 'acknowledged', 'Acknowledged' ], [ 'resolved', 'Resolved' ], [ 'dismissed', 'Dismissed' ], [ 'not-detected', 'No longer detected' ] ].forEach( ( [ value, label ] ) => reviewFilter.append( el( 'option', label, { value } ) ) );
 const ownerFilter = el( 'select', null, { 'aria-label': 'Issue assignment' } );
 [ [ '', 'Everyone' ], [ 'me', 'Assigned to me' ], [ 'unassigned', 'Unassigned' ] ].forEach( ( [ value, label ] ) => ownerFilter.append( el( 'option', label, { value } ) ) );
 const list = el( 'div', null );
 const detail = el( 'section', null, { class: 'maw-detail', tabindex: '-1', 'aria-label': 'Review details' } );
 const layout = el( 'div', null, { class: 'maw-layout' } ); layout.append( list, detail );
 root.replaceChildren( el( 'p', 'Review source records, resolve issues, and maintain editorial decisions. Your decisions are revisioned separately from generated builds.' ), message, controls, layout );
 const error = e => { message.textContent = e?.error?.info || e?.message || 'The request failed. Your saved decisions are unchanged. Reload and retry.'; };
 const get = p => api.get( { action: 'autowikidata', formatversion: 2, ...p } ).then( d => d.autowikidata );
 function table( headers, rows, onSelection = null ) {
  const node = el( 'div', null, { class: 'maw-table' } );
  const data = rows.map( ( row, id ) => ( { id, [TableRowIdentifier]: id, ...Object.fromEntries( row.map( ( v, i ) => [ 'c' + i, v ] ) ) } ) );
  const slots = Object.fromEntries( headers.map( ( _, i ) => [ 'item-c' + i, ( { item } ) => item instanceof Node ? h( 'span', { ref: container => { if ( container && !container.contains( item ) ) { container.append( item ); } } } ) : String( item ) ] ) );
  const selection = ref( [] );
  const app = createApp( { render: () => h( CdxTable, { useRowSelection: Boolean( onSelection ), selectedRows: selection.value, 'onUpdate:selectedRows': selected => { selection.value = selected; onSelection?.( selected ); }, caption: headers.join( ' / ' ), hideCaption: true, columns: headers.map( ( label, i ) => ( { id: 'c' + i, label } ) ), data }, slots ) } );
  app.mount( node );
  let attached = false;
  const observer = new MutationObserver( () => { if ( node.isConnected ) { attached = true; } else if ( attached ) { observer.disconnect(); app.unmount(); } } );
  observer.observe( root, { childList: true, subtree: true } );
  return node;
 }
 function showHistory( d ) {
  const a = el( 'a', 'History and source', { href: mw.util.getUrl( d.title || 'Special:Redirect/page/' + d.page, { action: 'history' } ), target: '_blank', rel: 'noopener' } );
  return a;
 }
 async function keyFor( target, type ) {
  const bytes = await crypto.subtle.digest( 'SHA-256', new TextEncoder().encode( target + ':' + type ) );
  return Array.from( new Uint8Array( bytes ), x => x.toString( 16 ).padStart( 2, '0' ) ).join( '' );
 }
 function editor( record, decisions, selected = null, issue = false ) {
  const sourceBuild = build;
  const form = el( 'form', null, { class: 'maw-form' } );
  form.append( el( 'h3', selected ? 'Edit decision' : 'Record a human decision' ) );
  const type = el( 'select', null, { 'aria-label': 'Decision type' } );
  const types = issue ? [ 'triage', 'assignment' ] : [ 'annotation', 'alias', 'visibility', 'match', 'reject', 'family', 'correction', 'report' ];
  types.forEach( t => type.append( el( 'option', t, { value: t } ) ) );
  const value = el( 'textarea', '', { rows: '3', maxlength: '8000', required: '', 'aria-label': 'Decision value' } );
  const reason = el( 'textarea', '', { rows: '2', maxlength: '2000', required: '', 'aria-label': 'Reason and evidence' } );
  const watch = el( 'input', null, { type: 'text', placeholder: 'Fields that this decision depends on, separated by commas', 'aria-label': 'Watched fields' } );
  const state = el( 'select', null, { 'aria-label': 'Decision state' } );
  for ( const t of [ 'active', 'revoked' ] ) { state.append( el( 'option', t, { value: t } ) ); }
  const hint = el( 'p', 'Annotations and aliases are plain text. Visibility: public or hidden. Match, reject and family: the candidate record ID. Corrections use a JSON value and watch exactly one field. Empty watched fields keep a decision applicable across source changes.' );
  if ( issue ) { hint.textContent = 'Set open, acknowledged, resolved or dismissed. Explain the resolution; detector evidence and your history are retained.'; }
  if ( selected ) { const d = selected.decision; type.value = d.type; type.disabled = true; value.value = d.value; reason.value = d.reason; watch.value = d.watch.join( ', ' ); state.value = d.state; }
  for ( const [ label, field ] of [ [ 'Type', type ], [ 'Value', value ], [ 'Reason and evidence', reason ], [ 'Source fields to watch', watch ], [ 'State', state ] ] ) { const wrapper = el( 'label', label ); wrapper.append( field ); form.append( wrapper ); }
  if ( issue && !selected ) { form.append( button( 'Assign to Me', () => { type.value = 'assignment'; value.value = mw.config.get( 'wgUserName' ) || ''; reason.focus(); } ) ); }
  const picker = el( 'div', null );
  const candidateQuery = el( 'input', null, { type: 'search', 'aria-label': 'Find a candidate', placeholder: 'Find an item or family by name' } );
  const candidates = el( 'div', null );
  picker.append( candidateQuery, button( 'Find candidates', async () => {
   try { const data = await get( { view: 'records', build: sourceBuild, query: candidateQuery.value } );
    const rejected = new Set( decisions.filter( d => d.decision.type === 'reject' && d.applicable && d.decision.state === 'active' ).map( d => d.decision.value ) );
    candidates.replaceChildren( ...data.rows.filter( r => !rejected.has( r.key ) ).slice( 0, 20 ).map( r => button( r.name + ' · ' + r.id, () => { value.value = r.key; candidates.replaceChildren( el( 'p', 'Selected: ' + r.name ) ); } ) ) );
   } catch ( e ) { error( e ); }
  } ), candidates );
  const showPicker = () => { picker.hidden = ![ 'match', 'reject', 'family' ].includes( type.value ); };
  type.addEventListener( 'change', showPicker ); showPicker(); form.append( picker, hint );
  const submit = el( 'button', 'Save decision', { type: 'submit', class: 'cdx-button' } ); form.append( submit );
  form.addEventListener( 'submit', async event => {
   event.preventDefault(); submit.disabled = true;
   try {
    const pairType = [ 'match', 'reject', 'family', 'correction' ].includes( type.value );
    const existing = selected || decisions.find( d => d.decision.type === type.value && ( !pairType || ( type.value === 'correction' ? d.decision.watch.join( ',' ) === watch.value.trim() : d.decision.value === value.value ) ) );
    const key = existing ? ( existing.title || '' ).split( ':' ).pop() : await keyFor( record.key, type.value + ( pairType ? ':' + ( type.value === 'correction' ? watch.value.trim() : value.value ) : '' ) );
    if ( existing && !selected ) { throw new Error( 'A decision of this type already exists. Use its Edit button to review it before changing it.' ); }
    const payload = { version: 1, target: selected?.decision.target || record.key, type: type.value, value: value.value, reason: reason.value, watch: watch.value.split( ',' ).map( s => s.trim() ).filter( Boolean ), fingerprint: issue ? record.fingerprint : selected?.decision.fingerprint || '0'.repeat( 64 ), state: state.value };
    const response = await api.postWithToken( 'csrf', { action: 'autowikidecision', operation: 'save', key, base: existing?.revision || 0, build: sourceBuild, payload: JSON.stringify( payload ), formatversion: 2 } );
    message.textContent = 'Saved revision ' + response.autowikidecision.revision + '. This decision is retained across imports.';
    if ( issue ) { await load(); } else { await openRecord( record.key ); }
   } catch ( e ) { error( e ); } finally { submit.disabled = false; }
  } );
  return form;
 }
 async function openDecision( d ) {
  if ( d.decision.type === 'preserve' ) { detail.replaceChildren( preservationControls( d ) );return; }
  if ( [ 'asset', 'asset-reject', 'triage', 'assignment' ].includes( d.decision.type ) ) {
   try { const data = await get( { view: 'issues', key: d.decision.target, build } );if ( data.issue ) { openIssue( data.issue ); } else { detail.replaceChildren( el( 'p', 'The source issue is unavailable. The human revision remains in history.' ), showHistory( d ) ); } } catch ( e ) { error( e ); }
  } else { await openRecord( d.decision.target ); }
 }
 function relinkControls( d ) {
  const box = el( 'section', null );box.append( el( 'strong', 'Identity link · ' + d.decision.state ), el( 'p', d.decision.reason ), showHistory( d ) );
  if ( d.decision.state !== 'active' ) { return box; }
  const form = el( 'form', null ), reason = el( 'input', null, { required: '', maxlength: '2000', 'aria-label': 'Reason to revoke identity link', placeholder: 'Why should these identities be separated?' } ), submit = el( 'button', 'Revoke Identity Link', { type: 'submit', class: 'cdx-button' } );form.append( reason, submit );
  form.addEventListener( 'submit', async event => { event.preventDefault();submit.disabled = true;try { await api.postWithToken( 'csrf', { action: 'autowikidecision', operation: 'save', build, key: d.title.split( ':' ).pop(), base: d.revision, payload: JSON.stringify( { ...d.decision, state: 'revoked', reason: reason.value } ) } );await openRecord( d.decision.target ); } catch ( e ) { error( e ); } finally { submit.disabled = false; } } );box.append( form );return box;
 }
 function relinkEditor( key, data ) {
  const previous = data.historical;if ( !previous ) { return el( 'p', 'No retained source record is available for identity comparison.' ); }
  const sourceBuild = build, prior = data.decisions.find( d => d.decision.type === 'relink' ), form = el( 'form', null, { class: 'maw-relink-form' } );let candidate;
  const search = el( 'input', null, { type: 'search', 'aria-label': 'Find replacement identity', value: previous.name } ), choices = el( 'div', null ), comparison = el( 'div', null ), reason = el( 'textarea', '', { required: '', maxlength: '2000', 'aria-label': 'Identity reconciliation evidence', placeholder: 'Explain why this is the same object or definition under a new source address.' } ), submit = el( 'button', 'Save Reviewed Identity Link', { type: 'submit', class: 'cdx-button', disabled: '' } );
  form.append( el( 'h3', 'Reconnect a Missing Identity' ), el( 'p', 'Previously recorded: ' + previous.name + ' · ' + previous.id + ' · Build ' + previous.build.slice( 0, 12 ) ), el( 'p', 'Compare a current record of the same kind. The original notes and revisions remain in place, and their watched facts are checked against the new source.' ), search, button( 'Find Current Candidates', async () => {
   try { const result = await get( { view: 'records', build: sourceBuild, kind: previous.kind, query: search.value } );choices.replaceChildren( ...result.rows.slice( 0, 20 ).map( r => button( r.name + ' · ' + r.id, async () => {
    try { const detail = await get( { view: 'records', build: sourceBuild, key: r.key } );if ( detail.missing ) { throw new Error( 'This candidate is no longer available.' ); }candidate = detail.record;comparison.replaceChildren( table( [ 'Evidence', 'Historical Source', 'Current Source' ], [ [ 'Source address', previous.id, candidate.id ], ...[ 'name', 'display_name', 'title', 'description', 'parent', 'documentation_id' ].map( field => [ field, JSON.stringify( previous.fields[field] ?? null ), JSON.stringify( candidate.fields[field] ?? null ) ] ) ] ) );submit.disabled = false; } catch ( e ) { error( e ); }
   } ) ) ); } catch ( e ) { error( e ); }
  } ), choices, comparison, reason, submit );
  form.addEventListener( 'submit', async event => { event.preventDefault();if ( !candidate ) { return; }submit.disabled = true;
   try { const decision = { version: 1, target: key, type: 'relink', value: JSON.stringify( { candidate: candidate.key, previousBuild: previous.build } ), reason: reason.value, watch: [], fingerprint: '0'.repeat( 64 ), state: 'active' };await api.postWithToken( 'csrf', { action: 'autowikidecision', operation: 'save', build: sourceBuild, key: prior ? prior.title.split( ':' ).pop() : await keyFor( key, 'relink' ), base: prior?.revision || 0, payload: JSON.stringify( decision ) } );message.textContent = 'Identity link saved. Original human revisions were retained.';await openRecord( key ); } catch ( e ) { error( e ); } finally { submit.disabled = false; }
  } );return form;
 }
 function preservationControls( row ) {
  const d = row.decision, value = JSON.parse( d.value ), box = el( 'section', null );
  box.append( el( 'strong', 'Preservation · ' + d.state + ' · Replacement ' + value.forBuild.slice( 0, 12 ) ), el( 'p', d.reason ), showHistory( row ), button( 'Review Preservation', () => {
   build = value.forBuild;if ( ![ ...buildSelect.options ].some( option => option.value === build ) ) { buildSelect.append( el( 'option', build.slice( 0, 12 ), { value: build } ) ); }buildSelect.value = build;detail.replaceChildren( preservationEditor( d.target, [ row ], row ) );
  } ) );
  if ( d.state === 'active' ) {
   const form = el( 'form', null ), reason = el( 'input', null, { required: '', maxlength: '2000', 'aria-label': 'Reason to revoke preservation' } ), submit = el( 'button', 'Revoke Preservation', { type: 'submit', class: 'cdx-button' } );form.append( reason, submit );
   form.addEventListener( 'submit', async event => { event.preventDefault();submit.disabled = true;try { await api.postWithToken( 'csrf', { action: 'autowikidecision', operation: 'save', build: value.forBuild, key: row.title.split( ':' ).pop(), base: row.revision, payload: JSON.stringify( { ...d, state: 'revoked', reason: reason.value } ) } );await openRecord( d.target ); } catch ( e ) { error( e ); } finally { submit.disabled = false; } } );box.append( form );
  }return box;
 }
 function preservationEditor( key, decisions, selected = null ) {
  detail.querySelector( '.maw-preservation-form' )?.remove();
  const sourceBuild = build, form = el( 'form', null, { class: 'maw-preservation-form' } ), choices = el( 'div', null ), comparison = el( 'div', null ), reason = el( 'textarea', selected?.decision.reason || '', { required: '', maxlength: '2000', 'aria-label': 'Preservation reason' } ), submit = el( 'button', 'Save Reviewed Preservation', { type: 'submit', class: 'cdx-button', disabled: '' } );let preview, publication, page = 0, request = 0, choicesRequest = 0, saving = false;
  const prior = selected || decisions.find( row => row.decision.type === 'preserve' && JSON.parse( row.decision.value ).forBuild === sourceBuild );
  form.append( el( 'h3', 'Preserve Published Data' ), el( 'p', 'Choose an actual publication and compare its source with this replacement. The choice applies only to replacement build ' + sourceBuild.slice( 0, 12 ) + '.' ), choices, comparison, reason, submit );
  if ( prior && !selected ) { choices.append( el( 'p', 'This replacement already has a preservation decision. Use Review Preservation to update it.' ) );return form; }
  const choose = async choice => {
   const current = ++request;submit.disabled = true;preview = null;comparison.replaceChildren( el( 'p', 'Loading the published-source comparison…' ) );
   try { const data = await get( { view: 'preservation', build: sourceBuild, key, publication: choice.id } );if ( current !== request ) { return; }
    if ( !data.eligible ) { comparison.replaceChildren( el( 'p', data.message ) );return; }preview = data;publication = choice.id;
    const currentFields = data.current?.fields || {}, retainedFields = data.retained.fields, fields = [ ...new Set( [ ...Object.keys( currentFields ), ...Object.keys( retainedFields ) ] ) ];
    const changed = fields.filter( field => JSON.stringify( currentFields[field] ) !== JSON.stringify( retainedFields[field] ) );
    comparison.replaceChildren( el( 'p', 'Published source: ' + data.retained.id + ' · Build ' + data.publication.sourceBuild.slice( 0, 12 ) ), el( 'p', data.current ? 'Replacement source: ' + data.current.id : 'This source record is absent from the replacement.' ), table( [ 'Changed Field', 'Replacement', 'Published Source' ], changed.map( field => [ field, JSON.stringify( currentFields[field] ?? null ), JSON.stringify( retainedFields[field] ?? null ) ] ) ) );
    const all = el( 'details', null );all.append( el( 'summary', 'Compare All Fields' ), table( [ 'Field', 'Replacement', 'Published Source' ], fields.map( field => [ field, JSON.stringify( currentFields[field] ?? null ), JSON.stringify( retainedFields[field] ?? null ) ] ) ) );comparison.append( all );submit.disabled = false;
   } catch ( e ) { if ( current === request ) { error( e ); } }
  };
  const loadChoices = async () => {
   const current = ++choicesRequest;
   try { const data = await get( { view: 'preservation', build: sourceBuild, key, offset: page * 50 } );if ( current !== choicesRequest ) { return; }choices.replaceChildren( ...data.rows.map( choice => button( choice.build.slice( 0, 12 ) + ' · ' + choice.published, () => { if ( !saving ) { choose( choice ); } } ) ) );
    if ( !data.rows.length ) { choices.append( el( 'p', 'No recorded publication contains this source. Imported drafts cannot be used as last-good data.' ) ); }
    const previous = button( 'Earlier Publication Page', () => { page--;loadChoices(); } ), next = button( 'More Publications', () => { page++;loadChoices(); } );previous.disabled = page === 0;next.disabled = !data.more;choices.append( previous, next );
   } catch ( e ) { if ( current === choicesRequest ) { error( e ); } }
  };
  form.addEventListener( 'submit', async event => { event.preventDefault();if ( !preview || saving ) { return; }saving = true;submit.disabled = true;
   try { const d = { version: 1, target: key, type: 'preserve', value: JSON.stringify( { forBuild: sourceBuild, publication } ), reason: reason.value, watch: [ 'preservation' ], fingerprint: preview.fingerprint, state: 'active' };
    await api.postWithToken( 'csrf', { action: 'autowikidecision', operation: 'save', build: sourceBuild, key: prior ? prior.title.split( ':' ).pop() : await keyFor( key, 'preserve:' + sourceBuild ), base: prior?.revision || 0, payload: JSON.stringify( d ) } );message.textContent = 'Preservation decision saved for this replacement build.';await openRecord( key );
   } catch ( e ) { error( e ); } finally { saving = false;submit.disabled = !preview; }
  } );loadChoices();return form;
 }
 async function openRecord( key ) {
  const request = ++serial; detail.replaceChildren( el( 'p', 'Loading record…' ) );
  try {
   const data = await get( { view: 'records', build, key } ); if ( request !== serial ) { return; }
   if ( data.missing ) { detail.replaceChildren( el( 'p', 'This record is absent from the selected build. Human decisions remain in history.' ), relinkEditor( key, data ), button( 'Preserve Published Data', () => detail.append( preservationEditor( key, data.decisions || [] ) ) ) ); for ( const d of data.decisions || [] ) { if ( d.decision.type === 'relink' ) { detail.append( relinkControls( d ) ); } else if ( d.decision.type === 'preserve' ) { detail.append( preservationControls( d ) ); } else { detail.append( showHistory( d ), editor( { key }, data.decisions, d ) ); } } return; }
   const r = data.record;
   detail.replaceChildren( el( 'h2', r.name ), el( 'code', r.key ), el( 'p', r.id ) );
   if ( data.image ) { const img = el( 'img', null, { src: data.image, alt: r.name, class: 'maw-icon-review' } ); detail.append( img, button( 'Toggle image background', () => img.classList.toggle( 'maw-icon-light' ) ) ); }
   const embed = el( 'details', null ), component = el( 'select', null, { 'aria-label': 'Reusable component' } ), field = el( 'select', null, { 'aria-label': 'Component field' } ), snippet = el( 'textarea', '', { readonly: '', rows: '2', 'aria-label': 'Wikitext to insert' } );
   [ 'Game Item', 'Game Fact', 'Game Icon', 'Game Recipe', 'Prose Dependency' ].forEach( name => component.append( el( 'option', name, { value: name } ) ) );
   Object.keys( r.fields ).forEach( name => field.append( el( 'option', name, { value: name } ) ) );
   const iconProfile = el( 'select', null, { 'aria-label': 'Component appearance profile' } );
   ( data.images || [] ).forEach( image => iconProfile.append( el( 'option', image.label, { value: image.profile } ) ) );
   const updateSnippet = () => { iconProfile.hidden = component.value !== 'Game Icon'; field.hidden = ![ 'Game Fact', 'Prose Dependency' ].includes( component.value ); snippet.value = component.value === 'Prose Dependency' ? '{{#gamedependency:' + r.key + '|' + field.value + '|SECTION_ANCHOR}}' : '{{' + component.value + '|id=' + r.key + ( field.hidden ? '' : '|field=' + field.value ) + ( iconProfile.hidden ? '' : '|profile=' + ( iconProfile.value || 'initial-south-first-frame' ) ) + '}}'; };
   iconProfile.addEventListener( 'change', updateSnippet ); component.addEventListener( 'change', updateSnippet ); field.addEventListener( 'change', updateSnippet ); updateSnippet();
   embed.append( el( 'summary', 'Use in a Guide' ), el( 'p', 'Choose a component and copy this wikitext into the guide. Values and links refresh automatically; your explanation stays yours.' ), component, field, iconProfile, snippet, button( 'Select Wikitext', () => { snippet.focus(); snippet.select(); } ) ); detail.append( embed );
   if ( data.images?.length > 1 || ( !data.image && data.images?.length ) ) {
    const chooser = el( 'select', null, { 'aria-label': 'Appearance profile' } ), preview = el( 'img', null, { alt: r.name, class: 'maw-icon-review' } ), scope = el( 'p', '' );
    data.images.forEach( image => chooser.append( el( 'option', image.label, { value: image.profile } ) ) );
    const show = () => { const image = data.images.find( i => i.profile === chooser.value ); preview.src = image.url; scope.textContent = image.scope; }; chooser.addEventListener( 'change', show ); show(); detail.append( chooser, preview, scope );
   }
   detail.append( el( 'p', 'Preview name: ' + data.effective.name + ( data.effective.conflicts.length ? ' · Decisions need revalidation' : '' ) ) );
   if ( data.guides.length ) { detail.append( el( 'h3', 'Used by guides' ) ); data.guides.forEach( g => detail.append( el( 'a', g.page + ' · ' + g.field, { href: g.url } ) ) ); }
   const fields = Object.entries( r.fields ).map( ( [ field, v ] ) => [ field, v === null ? 'Not specified / variable' : typeof v === 'object' ? JSON.stringify( v ) : String( v ), data.units[field] || '' ] );
   const source = el( 'details', null ); source.append( el( 'summary', 'Source fields and conditions' ), table( [ 'Field', 'Value', 'Unit' ], fields ) ); detail.append( source );
   detail.append( el( 'h3', 'Relationships' ), table( [ 'Direction', 'Relationship', 'Record' ], data.related.map( e => [ e.direction, e.field, e.record ? button( e.record.name, () => openRecord( e.record.key ) ) : 'Outside current export' ] ) ) );
   detail.append( el( 'h3', 'Editorial decisions' ) );
   data.decisions.forEach( d => {
    if ( d.decision.type === 'preserve' ) { detail.append( preservationControls( d ) );return; }
    if ( d.decision.type === 'relink' ) { detail.append( relinkControls( d ) );return; }
    if ( d.comparison?.length ) { detail.append( table( [ 'Changed assumption', 'Reviewed source', 'Selected source' ], d.comparison.map( row => [ row.field, JSON.stringify( row.reviewed ), JSON.stringify( row.current ) ] ) ) ); }
    const box = el( 'div', null, { class: 'maw-decision' } );
    box.append( el( 'strong', d.decision.type + ' · ' + ( d.decision.state === 'revoked' ? 'Revoked' : d.applicable ? 'Applies to this build' : 'Needs revalidation' ) ), el( 'p', d.decision.value ), el( 'p', d.decision.reason ), showHistory( d ), button( 'Edit', () => { const existing = detail.querySelector( '.maw-form' ); if ( existing ) { existing.remove(); } detail.append( editor( r, data.decisions, d ) ); } ) ); detail.append( box );
   } );
   detail.append( editor( r, data.decisions ), button( 'Preserve Published Data', () => detail.append( preservationEditor( r.key, data.decisions ) ) ) ); detail.focus();
  } catch ( e ) { error( e ); }
 }
 async function assetReview( issue, candidate, rejected = false ) {
  const data = await get( { view: 'records', build, key: candidate.key } );
  if ( data.missing || ( !data.image && !data.images?.length ) ) { throw new Error( 'The candidate has no validated image.' ); }
  const sourceBuild = build, r = data.record, decisionType = rejected ? 'asset-reject' : 'asset';
  const findPrior = profile => issue.decisions.find( d => d.decision.type === decisionType && ( !rejected || ( JSON.parse( d.decision.value ).entity === r.key && ( JSON.parse( d.decision.value ).profile || 'initial-south-first-frame' ) === profile ) ) );
  let prior = findPrior( candidate.profile || 'initial-south-first-frame' );
  const form = el( 'form', null, { class: 'maw-form' } );
  const profileSelect = el( 'select', null, { 'aria-label': 'Reviewed appearance profile' } );
  const available = data.images?.length ? data.images : [ { profile: 'initial-south-first-frame', label: 'Initial appearance', url: data.image, scope: r.fields.appearance_scope } ];
  const rejectedProfiles = new Set( issue.decisions.filter( d => d.decision.type === 'asset-reject' && d.applicable && JSON.parse( d.decision.value ).entity === r.key ).map( d => JSON.parse( d.decision.value ).profile || 'initial-south-first-frame' ) );
  available.forEach( image => profileSelect.append( el( 'option', image.label + ( rejectedProfiles.has( image.profile ) ? ' (Previously rejected)' : '' ), { value: image.profile } ) ) );
  const preferred = candidate.profile || ( prior ? JSON.parse( prior.decision.value ).profile || 'initial-south-first-frame' : available.find( image => !rejectedProfiles.has( image.profile ) )?.profile );
  profileSelect.value = available.some( image => image.profile === preferred ) ? preferred : available[0].profile;
  prior = findPrior( profileSelect.value );
  const chosenImage = el( 'img', null, { alt: r.name, class: 'maw-icon-review' } ), chosenScope = el( 'p', '' );
  const showProfile = () => { const image = available.find( i => i.profile === profileSelect.value ); if ( image ) { chosenImage.src = image.url; chosenScope.textContent = image.scope; } }; profileSelect.addEventListener( 'change', showProfile ); showProfile(); form.append( profileSelect, chosenImage, chosenScope );
  form.append( el( 'h3', 'Map ' + issue.observation.filename + ' to ' + r.name ), el( 'p', r.id + ' · ' + r.fields.icon_source + ' · ' + r.fields.icon_state ), el( 'p', 'Compare the object identity, appearance and attribution. Matching names or pixels alone do not establish identity.' ) );
  const reason = el( 'textarea', '', { required: '', maxlength: '2000', rows: '3', 'aria-label': 'Mapping evidence and attribution' } );
  reason.value = prior?.decision.reason || '';
  const priorHistory = el( 'div', null ); const showPrior = () => { prior = findPrior( profileSelect.value ); reason.value = prior?.decision.reason || ''; priorHistory.replaceChildren( ...( prior ? [ showHistory( prior ), el( 'p', 'Existing revision: ' + prior.revision ) ] : [] ) ); }; profileSelect.addEventListener( 'change', showPrior ); showPrior(); form.append( priorHistory );
  const submit = el( 'button', rejected ? 'Reject This Candidate' : 'Save Reviewed Mapping', { type: 'submit', class: 'cdx-button' } );form.append( reason, submit );
  form.addEventListener( 'submit', async event => {
   event.preventDefault();submit.disabled = true;
   try {
    const value = { entity: r.key, filename: issue.observation.filename, expectedImageHash: issue.observation.image_hash, profile: profileSelect.value };
    const decision = { version: 1, target: issue.id, type: decisionType, value: JSON.stringify( value ), reason: reason.value, watch: [], fingerprint: '0'.repeat( 64 ), state: 'active' };
    const result = await api.postWithToken( 'csrf', { action: 'autowikidecision', operation: 'save', build: sourceBuild, key: prior ? prior.title.split( ':' ).pop() : await keyFor( issue.id, decisionType + ( rejected ? ':' + r.key + ':' + profileSelect.value : '' ) ), base: prior?.revision || 0, payload: JSON.stringify( decision ), formatversion: 2 } );
    message.textContent = 'Mapping saved as revision ' + result.autowikidecision.revision + '. Publication uses the active validated build.';await load();
   } catch ( e ) { error( e ); } finally { submit.disabled = false; }
  } );
  detail.querySelector( '.maw-form' )?.remove();detail.append( form );form.scrollIntoView?.( { block: 'nearest' } );
 }
 function detectorLabel( state ) { return { detected: 'Detected', 'not-detected': 'No longer detected', 'source-absent': 'Source absent from scan' }[state] || 'Not scanned'; }
 function openIssue( issue ) {
  detail.replaceChildren( el( 'h2', issue.rule ), el( 'p', issue.observation.name || issue.target ), el( 'p', issue.observation.reason || '' ), el( 'p', 'First seen: ' + issue.first_seen + ' · Latest observation: ' + issue.last_seen ), button( 'Inspect source record', () => openRecord( issue.target ) ) );
  if ( issue.detection ) {
   const detection = issue.detection;
   detail.append( el( 'p', detectorLabel( detection.state ) + '. Human review is unchanged. Last complete scan: ' + detection.checked + ' · Build: ' + detection.build.slice( 0, 12 ) ) );
   const history = el( 'details', null ), content = el( 'div', null );let historyOffset = 0, historyRequest = 0;history.append( el( 'summary', 'Detector History' ), content );
   const loadHistory = async () => {
    const request = ++historyRequest;content.replaceChildren( el( 'p', 'Loading history…' ) );
    try {
     const data = await get( { view: 'issues', key: issue.id, offset: historyOffset } );if ( request !== historyRequest ) { return; }
     const events = data.issue?.detection?.history || [];
     const rows = events.map( event => { const evidence = el( 'details', null );evidence.append( el( 'summary', 'View observed evidence' ), el( 'pre', JSON.stringify( event.observation, null, 2 ) ) );return [ event.observed, detectorLabel( event.state ), event.build.slice( 0, 12 ), evidence ]; } );
     const previous = button( 'Newer Detector Events', () => { historyOffset -= 20;loadHistory(); } ), next = button( 'Older Detector Events', () => { historyOffset += 20;loadHistory(); } );previous.disabled = historyOffset === 0;next.disabled = !data.issue?.detection?.moreHistory;
     content.replaceChildren( table( [ 'Observed', 'Detector Result', 'Build', 'Evidence' ], rows ), previous, next );
    } catch ( e ) { if ( request === historyRequest ) { content.replaceChildren( el( 'p', 'History could not be loaded.' ), button( 'Retry Detector History', loadHistory ) );error( e ); } }
   };
   history.addEventListener( 'toggle', () => { if ( history.open && !content.childNodes.length ) { loadHistory(); } } );detail.append( history );
  }
  if ( issue.rule === 'legacy-image' ) {
   detail.append( el( 'img', null, { src: issue.observation.image_url, alt: issue.observation.filename, class: 'maw-icon-review' } ), el( 'p', issue.observation.uses + ' wiki uses' ) );
   const rejected = new Set( issue.decisions.filter( d => d.decision.type === 'asset-reject' && d.applicable ).map( d => JSON.parse( d.decision.value ).entity ) );
   const showCandidate = candidate => { const row = el( 'div', null ); row.append( button( candidate.name + ( candidate.samePixels ? ' · Same pixels' : '' ) + ( rejected.has( candidate.key ) ? ' · Has rejected profiles' : '' ), () => assetReview( issue, candidate ).catch( error ) ), button( 'Reject ' + candidate.name, () => assetReview( issue, candidate, true ).catch( error ) ) ); return row; };
   for ( const candidate of issue.observation.candidates ) { const row = showCandidate( candidate ); if ( row ) { detail.append( row ); } }
   const search = el( 'input', null, { type: 'search', 'aria-label': 'Find image source', placeholder: 'Find another source item' } ), found = el( 'div', null );
   detail.append( search, button( 'Find Image Candidates', async () => { try { const data = await get( { view: 'records', build, kind: 'entity', query: search.value } ); found.replaceChildren( ...data.rows.slice( 0, 20 ).map( showCandidate ).filter( Boolean ) ); } catch ( e ) { error( e ); } } ), found );
   for ( const d of issue.decisions.filter( d => [ 'asset', 'asset-reject' ].includes( d.decision.type ) ) ) {
    const mapping = JSON.parse( d.decision.value );detail.append( el( 'p', d.decision.type + ' · ' + ( mapping.profile || 'initial-south-first-frame' ) + ': ' + d.decision.reason + ' (' + d.decision.state + ')' ), showHistory( d ), button( 'Review Mapping', () => assetReview( issue, { key: mapping.entity, profile: mapping.profile || 'initial-south-first-frame' }, d.decision.type === 'asset-reject' ).catch( error ) ) );
    if ( d.decision.state === 'active' ) { detail.append( button( 'Revoke Decision', async () => { try { await api.postWithToken( 'csrf', { action: 'autowikidecision', build, key: d.title.split( ':' ).pop(), base: d.revision, payload: JSON.stringify( { ...d.decision, state: 'revoked', reason: 'Revoked from the reviewed image history.' } ) } ); message.textContent = 'Decision revoked; history retained.'; await load(); } catch ( e ) { error( e ); } } ) ); }
   }
   if ( !issue.observation.candidates.length ) { detail.append( el( 'p', 'No automatic candidate. Search the record catalogue to investigate the source.' ) ); }
  }
  issue.decisions.filter( d => [ 'triage', 'assignment' ].includes( d.decision.type ) ).forEach( d => detail.append( el( 'p', d.decision.type + ': ' + d.decision.value + ' · ' + d.decision.reason ), showHistory( d ), button( 'Edit', () => { detail.querySelector( '.maw-form' )?.remove(); detail.append( editor( { key: issue.id, fingerprint: issue.fingerprint }, issue.decisions, d, true ) ); } ) ) );
  detail.append( editor( { key: issue.id, fingerprint: issue.fingerprint }, issue.decisions, null, true ) ); detail.focus();
 }
 function bulkEditor( issues ) {
  const sourceBuild = build, box = el( 'section', null, { class: 'maw-form' } );
  if ( issues.length > 20 ) { box.append( el( 'p', 'Select at most 20 issues for one review.' ) ); return box; }
  box.append( el( 'h3', 'Review ' + issues.length + ' selected issues' ) );
  const state = el( 'select', null, { 'aria-label': 'Bulk review state' } );
  [ 'acknowledged', 'resolved', 'dismissed', 'open' ].forEach( v => state.append( el( 'option', v, { value: v } ) ) );
  const reason = el( 'textarea', '', { rows: '2', maxlength: '2000', 'aria-label': 'Bulk review reason', placeholder: 'Explain the decision for every selected issue' } );
  const preview = el( 'div', null );
  box.append( state, reason, button( 'Preview Selected Changes', async () => {
   if ( !reason.value.trim() ) { message.textContent = 'Enter a reason before previewing these decisions.'; return; }
   const entries = [];
   for ( const issue of issues ) {
    const prior = issue.decisions.filter( d => d.decision.type === 'triage' ).at( -1 );
    entries.push( { key: prior ? prior.title.split( ':' ).pop() : await keyFor( issue.id, 'triage' ), base: prior?.revision || 0, decision: { version: 1, target: issue.id, type: 'triage', value: state.value, reason: reason.value, watch: [ 'observation' ], fingerprint: issue.fingerprint, state: 'active' } } );
   }
   preview.replaceChildren( el( 'p', 'Set these issues to ' + state.value + ': ' + issues.map( i => i.observation.name || i.rule ).join( '; ' ) ), el( 'p', reason.value ), button( 'Apply Reviewed Changes', async event => {
    const control = event.currentTarget; control.disabled = true;
    try { const result = await api.postWithToken( 'csrf', { action: 'autowikidecision', operation: 'bulk', build: sourceBuild, payload: JSON.stringify( entries ), formatversion: 2 } );
     const results = result.autowikidecision.results, failed = results.filter( r => !r.ok );
     message.textContent = ( results.length - failed.length ) + ' saved; ' + failed.length + ' require a fresh review.' + ( failed.length ? ' ' + [ ...new Set( failed.map( r => r.error ) ) ].join( ' ' ) : '' ); await load();
    } catch ( e ) { error( e ); control.disabled = false; }
   } ) );
  } ), preview );
  return box;
 }
 async function load() {
  const request = ++listSerial; ++serial;
  query.placeholder = view === 'publication' ? 'Find findings by rule or source' : 'Find a record by name';
  const url = new URL( location.href ); url.searchParams.set( 'awview', view ); url.searchParams.set( 'awquery', query.value ); url.searchParams.set( 'awbuild', build ); url.searchParams.set( 'awstate', reviewFilter.value ); url.searchParams.set( 'awowner', ownerFilter.value ); history.replaceState( null, '', url );
  reviewFilter.hidden = ownerFilter.hidden = view !== 'issues'; list.replaceChildren( el( 'p', 'Loading…' ) );
  try {
   if ( view === 'publications' ) {
    status = await get( { view: 'status' } ); if ( request !== listSerial ) { return; }
    if ( status.deployment ) { message.textContent = status.deployment.message + ( status.deployment.commit ? ' Running source: ' + status.deployment.commit.slice( 0, 12 ) + '.' : '' ) + ( status.deployment.engine ? ' BYOND ' + status.deployment.engine + '.' : '' ); }
    if ( status.editorialPending ) { message.textContent += ' Applying recent editorial changes. Public references will return when processing finishes.'; }
    if ( Number.isSafeInteger( status.deployment?.buildRunId ) && status.deployment.buildRunId > 0 ) { const runLink = el( 'a', 'View Generation Run' ); runLink.href = 'https://github.com/Aphelion-Moon/Meridian-Rift/actions/runs/' + status.deployment.buildRunId; runLink.target = '_blank'; runLink.rel = 'noopener noreferrer'; message.append( ' ', runLink ); }
    list.replaceChildren( table( [ 'Build', 'State', 'Source', 'Records' ], status.builds.map( b => [ button( b.id.slice( 0, 12 ), () => { build = b.id; buildSelect.value = build; view = 'records'; offset = 0; load(); } ), b.id === status.active ? 'Active' : b.publicationReady ? b.status : 'Review build', b.source.slice( 0, 12 ), Object.values( b.counts ).reduce( ( a, v ) => a + v, 0 ) ] ) ) );
    detail.replaceChildren( el( 'h2', 'Publication state' ), el( 'p', status.active ? 'Active build: ' + status.active : 'No structured build is public yet.' ), el( 'p', 'Review builds can be inspected and annotated. Public activation requires a clean package and publication permission.' ), table( [ 'Stage', 'State', 'Attempts', 'Last error' ], status.outbox.map( o => [ o.type, o.status, o.attempts, o.status === 'failed' && status.canPublish ? button( 'Retry delivery', async () => { try { await api.postWithToken( 'csrf', { action: 'autowikidecision', operation: 'retry', build, key: o.id } ); await load(); } catch ( e ) { error( e ); } } ) : o.error ] ) ) );
    if ( status.operations ) {
     const health = status.operations;
     const summary = el( 'div' );
     summary.append( el( 'h2', 'Service Health' ), el( 'p', health.queue.pending + ' pending · ' + health.queue.failed + ' failed · ' + health.queue.done + ' completed deliveries. All deliveries are counted; the table shows up to 100, with unresolved work first.' ) );
     if ( health.findings.length ) { summary.append( table( [ 'State', 'Action' ], health.findings.map( f => [ f.severity, f.message ] ) ) ); }
     detail.prepend( summary );
    }
    if ( build ) { detail.append( button( 'Publication Findings', () => { view = 'publication'; offset = 0; load(); } ) ); }
    if ( status.canPublish && build ) {
     detail.append( button( 'Prepare Selected Build', async () => { try { await api.postWithToken( 'csrf', { action: 'autowikidecision', operation: 'prepare', build } ); message.textContent = 'Preparation queued. Refresh Publications for delivery status.'; } catch ( e ) { error( e ); } } ), button( 'Preview Activation', () => {
      const selectedBuild = build, expected = status.active;
      const preview = el( 'section', null );preview.append( el( 'p', 'Activate ' + selectedBuild + '. Previous build: ' + ( expected || 'none' ) + '. Human revisions will remain intact. The server checks release provenance, current decisions and prepared search.' ), button( 'Activate Reviewed Build', async () => { try { await api.postWithToken( 'csrf', { action: 'autowikidecision', operation: 'activate', build: selectedBuild, expected } ); message.textContent = 'Build activated.';await load(); } catch ( e ) { error( e ); } } ) );detail.append( preview );
     } ) );
    }
    return;
   }
   const data = await get( { view, build, query: query.value, offset, reviewstate: reviewFilter.value, assignee: ownerFilter.value } ); if ( request !== listSerial ) { return; }
   if ( view === 'decisions' ) { list.replaceChildren( table( [ 'Decision', 'Value', 'History' ], data.rows.map( d => [ button( d.decision.type, () => openDecision( d ) ), d.decision.value, showHistory( d ) ] ) ) ); }
   else if ( view === 'guides' ) { list.replaceChildren( table( [ 'Guide', 'Section or Fact', 'Field' ], data.rows.map( g => [ el( 'a', g.page, { href: g.url } ), g.anchor || 'Whole page', g.field || 'Whole record' ] ) ) ); }
   else if ( view === 'publication' ) {
    detail.replaceChildren( el( 'h2', 'Publication Findings' ), el( 'p', data.gate ? data.gate.findings + ' findings · ' + data.gate.status + '. These are generated checks; your editorial decisions remain separate.' : 'No authenticated publication assessment is available for this build.' ) );
    list.replaceChildren( table( [ 'Finding', 'Source', 'Evidence' ], data.rows.map( r => [ r.rule.replace( /-/g, ' ' ), r.key ? button( r.observation.target || r.key, () => openRecord( r.key ) ) : r.observation.target || 'Whole build', JSON.stringify( r.observation ) ] ) ) );
   }
   else {
   const rows = view === 'issues' ? data.rows.map( r => [ button( r.observation.name || r.rule, () => openIssue( r ) ), r.rule, r.review_state || 'open', r.detection ? detectorLabel( r.detection.state ) : 'Not scanned', r.assignee || 'Unassigned', r.uses || 0 ] ) : data.rows.map( r => [ button( r.name, () => openRecord( r.key ) ), r.kind, r.id ] );
   let selected = [];
   const bulk = el( 'div', null );
   list.replaceChildren( table( view === 'issues' ? [ 'Issue', 'Type', 'Review state', 'Detector', 'Assigned to', 'Wiki uses' ] : [ 'Name', 'Kind', 'Source identity' ], rows, view === 'issues' ? ids => { selected = ids.map( i => data.rows[i] ); bulk.replaceChildren( selected.length ? bulkEditor( selected ) : el( 'span', '' ) ); } : null ), bulk );
   if ( view === 'issues' && data.groups ) { const groups = el( 'details', null );groups.append( el( 'summary', 'Group by cause' ) );data.groups.forEach( group => groups.append( button( group.rule + ' (' + group.count + ')', () => { query.value = group.rule; offset = 0; load(); } ) ) );list.prepend( groups ); }
   if ( !rows.length ) { list.append( el( 'p', 'No matching records.' ) ); }
   }
   const previous = button( 'Previous', () => { offset = Math.max( 0, offset - 50 ); load(); } ); previous.disabled = offset === 0;
   const next = button( 'Next', () => { offset += 50; load(); } ); next.disabled = !data.more;
   list.append( previous, el( 'span', ' Page ' + ( offset / 50 + 1 ) + ' ' ), next );
  } catch ( e ) { error( e ); }
 }
 async function init() {
  status = await get( { view: 'status' } ); const url = new URL( location.href ); build = status.builds.some( b => b.id === url.searchParams.get( 'awbuild' ) ) ? url.searchParams.get( 'awbuild' ) : status.active || status.builds[0]?.id || ''; query.value = url.searchParams.get( 'awquery' ) || ''; const requestedView = url.searchParams.get( 'awview' ); if ( [ 'records', 'issues', 'decisions', 'guides', 'publications', 'publication' ].includes( requestedView ) ) { view = requestedView; }
  status.builds.forEach( b => buildSelect.append( el( 'option', b.source.slice( 0, 10 ) + ' · ' + ( b.id === status.active ? 'Active' : b.publicationReady ? 'Staged' : 'Review' ), { value: b.id } ) ) ); buildSelect.value = build;
  if ( [ ...reviewFilter.options ].some( o => o.value === url.searchParams.get( 'awstate' ) ) ) { reviewFilter.value = url.searchParams.get( 'awstate' ); }
  if ( [ '', 'me', 'unassigned' ].includes( url.searchParams.get( 'awowner' ) ) ) { ownerFilter.value = url.searchParams.get( 'awowner' ); }
  [ reviewFilter, ownerFilter ].forEach( control => control.addEventListener( 'change', () => { offset = 0; load(); } ) );
  buildSelect.addEventListener( 'change', () => { build = buildSelect.value; offset = 0; detail.replaceChildren(); load(); } );
  controls.append( buildSelect, query, reviewFilter, ownerFilter, button( 'Find', () => { offset = 0; load(); } ), button( 'Records', () => { view = 'records'; offset = 0; load(); } ), button( 'Needs Attention', () => { view = 'issues'; offset = 0; load(); } ), button( 'Editorial Decisions', () => { view = 'decisions'; offset = 0; load(); } ), button( 'Guide Impact', () => { view = 'guides'; offset = 0; load(); } ), button( 'Publications', () => { view = 'publications'; load(); } ) );
  query.addEventListener( 'keydown', event => { if ( event.key === 'Enter' ) { offset = 0; load(); } } );
  message.textContent = status.builds.length + ' builds available. Human decisions are saved independently of generated data.'; await load(); const requestedRecord = url.searchParams.get( 'awrecord' ); if ( /^[a-f0-9]{64}$/.test( requestedRecord || '' ) ) { await openRecord( requestedRecord ); }
 }
 init().catch( error );
} );

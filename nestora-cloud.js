(() => {
  const config = window.NESTORA_CONFIG || {};
  let client;
  const result = (data, error) => { if (error) throw error; return data; };
  const unwrap = async promise => { const { data, error } = await promise; return result(data, error); };
  window.NestoraCloud = {
    configured() {
      return Boolean(window.supabase?.createClient && config.supabaseUrl?.startsWith('https://') &&
        config.supabaseAnonKey && !config.supabaseUrl.includes('YOUR-PROJECT') && !config.supabaseAnonKey.includes('YOUR-PUBLISHABLE'));
    },
    initialize() {
      if (!this.configured()) throw new Error('Nestora cloud is not configured. Add the Supabase URL and public key to cloud-config.js.');
      client ||= window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey, {
        auth: { autoRefreshToken: true, persistSession: true, detectSessionInUrl: true }
      });
      return client;
    },
    get client() { return client; },
    async signUp(email, password) { return unwrap(this.initialize().auth.signUp({ email, password })); },
    async signIn(email, password) { return unwrap(this.initialize().auth.signInWithPassword({ email, password })); },
    async signOut() { return unwrap(this.initialize().auth.signOut()); },
    onAuthStateChange(callback) { return this.initialize().auth.onAuthStateChange(callback); },
    async requestAccess(user) {
      const { error } = await client.from('portfolio_access_requests').upsert({ user_id: user.id, email: user.email }, { onConflict: 'user_id', ignoreDuplicates: true });
      if (error) throw error;
    },
    async membership(userId) {
      const { data, error } = await client.from('portfolio_memberships').select('role').eq('user_id', userId).maybeSingle();
      if (error) throw error;
      return data?.role || null;
    },
    async loadPortfolio() {
      const { data, error } = await client.from('portfolio_state').select('payload,revision,updated_at').eq('id', 'shared').single();
      return result(data, error);
    },
    async savePortfolio(payload, revision) {
      const { data, error } = await client.rpc('save_nestora_portfolio', { p_payload: payload, p_expected_revision: revision });
      return result(data, error);
    },
    async refreshPortfolio() {
      return this.loadPortfolio();
    },
    async uploadDocument(file, propertyId, documentId) {
      const safeName = String(file.name || 'document').normalize('NFKC').replace(/[^a-zA-Z0-9._-]/g, '_').slice(-100) || 'document';
      const path = `shared/${documentId}/${safeName}`;
      const { error } = await client.storage.from('nestora-documents').upload(path, file, { contentType: file.type || 'application/octet-stream', upsert: false });
      if (error) throw error;
      return path;
    },
    async downloadDocument(path) {
      const { data, error } = await client.storage.from('nestora-documents').download(path);
      return result(data, error);
    },
    async removeDocuments(paths) {
      const unique = [...new Set(paths.filter(Boolean))];
      if (!unique.length) return;
      const { error } = await client.storage.from('nestora-documents').remove(unique);
      if (error) throw error;
    },
    async accessRequests() {
      const { data, error } = await client.from('portfolio_access_requests').select('user_id,email,requested_at').order('requested_at');
      return result(data, error);
    },
    async approveAccess(request, role = 'editor') {
      const { error: addError } = await client.from('portfolio_memberships').upsert({ user_id: request.user_id, email: request.email, role }, { onConflict: 'user_id' });
      if (addError) throw addError;
      const { error: deleteError } = await client.from('portfolio_access_requests').delete().eq('user_id', request.user_id);
      if (deleteError) throw deleteError;
    },
    async denyAccess(userId) {
      const { error } = await client.from('portfolio_access_requests').delete().eq('user_id', userId);
      if (error) throw error;
    },
    async setMemberRole(userId, role) {
      const { error } = await client.from('portfolio_memberships').update({ role }).eq('user_id', userId);
      if (error) throw error;
    },
    async members() {
      const { data, error } = await client.from('portfolio_memberships').select('user_id,email,role,created_at').order('created_at');
      return result(data, error);
    },
    async removeMember(userId) {
      const { error } = await client.from('portfolio_memberships').delete().eq('user_id', userId);
      if (error) throw error;
    }
  };
})();

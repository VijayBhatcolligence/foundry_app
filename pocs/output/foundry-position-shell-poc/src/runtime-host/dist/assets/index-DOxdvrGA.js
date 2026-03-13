(function(){const e=document.createElement("link").relList;if(e&&e.supports&&e.supports("modulepreload"))return;for(const o of document.querySelectorAll('link[rel="modulepreload"]'))s(o);new MutationObserver(o=>{for(const i of o)if(i.type==="childList")for(const n of i.addedNodes)n.tagName==="LINK"&&n.rel==="modulepreload"&&s(n)}).observe(document,{childList:!0,subtree:!0});function t(o){const i={};return o.integrity&&(i.integrity=o.integrity),o.referrerPolicy&&(i.referrerPolicy=o.referrerPolicy),o.crossOrigin==="use-credentials"?i.credentials="include":o.crossOrigin==="anonymous"?i.credentials="omit":i.credentials="same-origin",i}function s(o){if(o.ep)return;o.ep=!0;const i=t(o);fetch(o.href,i)}})();class v{constructor(){this.bridge=null,this.session=null,this.positionContext=null,this.moduleStatus="unloaded",this.currentModule=null,this.eventHandlers=[],this._initializeBridge()}_initializeBridge(){window.shellBridge?(this.bridge=window.shellBridge,this._log("info","Flutter bridge detected")):(this.bridge=this._createMockBridge(),this._log("warn","Using mock bridge (not in Flutter WebView)"))}_createMockBridge(){return{postMessage:async(e,t)=>{switch(this._log("info",`Mock bridge call: ${e}`,t),e){case"getBootstrapCode":return{success:!0,data:{bootstrapCode:"mock_bootstrap_"+Date.now(),expiresAt:new Date(Date.now()+6e4).toISOString(),positionId:"WAREHOUSE-CLERK-01"}};case"redeemBootstrap":return{success:!0,data:{sessionId:"mock_session_"+Date.now(),positionId:"WAREHOUSE-CLERK-01",orgId:"ORG001",roleContext:{department:"Warehouse Operations",location:"Building A - Zone 3",permissions:["inventory.view","inventory.count"],warehouseZone:"ZONE-A3"},expiresAt:new Date(Date.now()+8*36e5).toISOString()}};case"validateSession":return{success:!0,data:{valid:!0,session:this.session}};case"getPositionContext":return{success:!0,data:{position:{orgId:"ORG001",positionId:"WAREHOUSE-CLERK-01",positionName:"Warehouse Clerk",roleContext:{department:"Warehouse Operations",location:"Building A - Zone 3",permissions:["inventory.view","inventory.count"]}}}};default:return{success:!0,data:{}}}}}}async initialize(){try{this._updateStatus("Runtime Host: Bootstrapping..."),this._log("info","Starting runtime initialization");const e=await this._callBridge("getBootstrapCode",{});if(!e.success)throw new Error("Failed to get bootstrap code: "+e.error);const{bootstrapCode:t,positionId:s}=e.data;this._log("info","Bootstrap code received",{positionId:s});const o=await this._callBridge("redeemBootstrap",{bootstrapCode:t});if(!o.success)throw new Error("Bootstrap redemption failed: "+o.error);this.session=o.data,this._log("info","Scoped session created",{sessionId:this.session.sessionId,positionId:this.session.positionId}),this._emitEvent({type:"bootstrap_redeemed",session:this.session});const i=await this._callBridge("getPositionContext",{});i.success&&(this.positionContext=i.data.position),this._updateStatus(`Runtime Host: Ready (Position: ${this.session.positionId})`),this._emitEvent({type:"runtime_ready"}),this._log("info","Runtime host initialized successfully");const n=document.getElementById("loading-overlay");return n&&(n.style.display="none"),!0}catch(e){return this._log("error","Runtime initialization failed",e),this._showError("Failed to initialize runtime: "+e.message),!1}}async mountModule(e){try{this.moduleStatus="loading",this._emitEvent({type:"module_loading",moduleId:e.moduleId}),this._log("info","Mounting module",e);const t=document.getElementById("module-container");if(!t)throw new Error("Module container not found");t.innerHTML="";const s=this._createRuntimeAPI();return this.moduleStatus="initializing",await new Promise(o=>setTimeout(o,500)),this._renderModulePlaceholder(t),this.moduleStatus="mounted",this.currentModule=e,this._emitEvent({type:"module_mounted",moduleId:e.moduleId}),this._log("info","Module mounted successfully",{moduleId:e.moduleId}),!0}catch(t){throw this.moduleStatus="error",this._emitEvent({type:"module_error",moduleId:e.moduleId,error:t.message}),this._log("error","Module mount failed",t),t}}async unmountModule(){var e;if(!this.currentModule){this._log("warn","No module to unmount");return}try{this.moduleStatus="unmounting",this._log("info","Unmounting module",{moduleId:this.currentModule.moduleId}),await this._callBridge("unmountModule",{sessionId:(e=this.session)==null?void 0:e.sessionId});const t=document.getElementById("module-container");t&&(t.innerHTML="");const s=this.currentModule.moduleId;this.currentModule=null,this.moduleStatus="unloaded",this._emitEvent({type:"module_unmounted",moduleId:s}),this._log("info","Module unmounted successfully")}catch(t){throw this._log("error","Module unmount failed",t),t}}_createRuntimeAPI(){return{getSession:()=>this.session,getPositionContext:()=>this.positionContext,validateSession:async()=>{var t;const e=await this._callBridge("validateSession",{sessionId:(t=this.session)==null?void 0:t.sessionId});return e.success&&e.data.valid},log:(e,t,s)=>{this._log(e,`[Module] ${t}`,s)},requestUnmount:async()=>{await this.unmountModule()}}}_renderModulePlaceholder(e){var t,s,o,i,n,a,l,u,c,m,h,p,g;e.innerHTML=`
      <div style="padding: 24px;">
        <div style="background: white; border-radius: 8px; padding: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
          <h2 style="margin-bottom: 16px; color: #1976d2;">
            ${((t=this.positionContext)==null?void 0:t.positionName)||"Position Module"}
          </h2>

          <div style="margin-bottom: 24px;">
            <h3 style="font-size: 14px; font-weight: 600; margin-bottom: 8px; color: #666;">
              Position Context
            </h3>
            <div style="background: #f5f5f5; padding: 12px; border-radius: 4px; font-family: monospace; font-size: 12px;">
              <div><strong>Org ID:</strong> ${(s=this.positionContext)==null?void 0:s.orgId}</div>
              <div><strong>Position ID:</strong> ${(o=this.positionContext)==null?void 0:o.positionId}</div>
              <div><strong>Department:</strong> ${(n=(i=this.positionContext)==null?void 0:i.roleContext)==null?void 0:n.department}</div>
              <div><strong>Location:</strong> ${(l=(a=this.positionContext)==null?void 0:a.roleContext)==null?void 0:l.location}</div>
            </div>
          </div>

          <div style="margin-bottom: 24px;">
            <h3 style="font-size: 14px; font-weight: 600; margin-bottom: 8px; color: #666;">
              Scoped Session (Active)
            </h3>
            <div style="background: #e8f5e9; padding: 12px; border-radius: 4px; font-family: monospace; font-size: 12px;">
              <div><strong>Session ID:</strong> ${(c=(u=this.session)==null?void 0:u.sessionId)==null?void 0:c.substring(0,16)}...</div>
              <div><strong>Expires:</strong> ${new Date((m=this.session)==null?void 0:m.expiresAt).toLocaleString()}</div>
              <div style="color: #2e7d32; margin-top: 8px;">
                ✓ Scoped session active (shell token not accessible)
              </div>
            </div>
          </div>

          <div>
            <h3 style="font-size: 14px; font-weight: 600; margin-bottom: 8px; color: #666;">
              Permissions
            </h3>
            <div style="display: flex; flex-wrap: wrap; gap: 8px;">
              ${((g=(p=(h=this.positionContext)==null?void 0:h.roleContext)==null?void 0:p.permissions)==null?void 0:g.map(f=>`<span style="background: #1976d2; color: white; padding: 4px 12px; border-radius: 12px; font-size: 12px;">${f}</span>`).join(""))||""}
            </div>
          </div>
        </div>
      </div>
    `}async _callBridge(e,t){try{return await this.bridge.postMessage(e,t)}catch(s){return this._log("error",`Bridge call failed: ${e}`,s),{success:!1,error:s.message}}}_updateStatus(e){const t=document.getElementById("runtime-status");t&&(t.textContent=e)}_showError(e){const t=document.getElementById("module-container");t&&(t.innerHTML=`
        <div class="error-container">
          <div class="error-message">${e}</div>
        </div>
      `),this._updateStatus("Runtime Host: Error")}_log(e,t,s){const o=`[RuntimeHost] ${t}`;s?console[e](o,s):console[e](o)}_emitEvent(e){this.eventHandlers.forEach(t=>t(e))}on(e){this.eventHandlers.push(e)}getModuleStatus(){return{status:this.moduleStatus,module:this.currentModule,session:this.session?{sessionId:this.session.sessionId,positionId:this.session.positionId,expiresAt:this.session.expiresAt}:null}}}let r;document.addEventListener("DOMContentLoaded",async()=>{console.log("[RuntimeHost] Initializing..."),r=new v,await r.initialize()&&await r.mountModule({moduleId:"sample-warehouse",moduleName:"Warehouse Operations",moduleUrl:"/modules/sample-warehouse/index.js",version:"1.0.0"})});window.runtimeHost=r;

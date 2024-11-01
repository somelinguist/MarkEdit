import { WebModule } from '../webModule';
import {
  ReplaceGranularity,
  resetEditor,
  clearEditor,
  getEditorText,
  insertText,
  replaceText,
  handleFocusLost,
  handleMouseExited,
} from '../../core';

/**
 * @shouldExport true
 * @invokePath core
 * @overrideModuleName WebBridgeCore
 */
export interface WebModuleCore extends WebModule {
  resetEditor({ text, revision, revisionMode }: { text: string; revision?: string; revisionMode: boolean }): void;
  clearEditor(): void;
  getEditorText(): string;
  insertText({ text, from, to }: { text: string; from: CodeGen_Int; to: CodeGen_Int }): void;
  replaceText({ text, granularity }: { text: string; granularity: ReplaceGranularity }): void;
  handleFocusLost(): void;
  handleMouseExited({ clientX, clientY }: { clientX: number; clientY: number }): void;
}

export class WebModuleCoreImpl implements WebModuleCore {
  resetEditor({ text, revision, revisionMode }: { text: string; revision?: string; revisionMode: boolean }): void {
    resetEditor(text, revision, revisionMode);
  }

  clearEditor(): void {
    clearEditor();
  }

  getEditorText(): string {
    return getEditorText();
  }

  insertText({ text, from, to }: { text: string; from: CodeGen_Int; to: CodeGen_Int }): void {
    insertText(text, from, to);
  }

  replaceText({ text, granularity }: { text: string; granularity: ReplaceGranularity }): void {
    replaceText(text, granularity);
  }

  handleFocusLost(): void {
    handleFocusLost();
  }

  handleMouseExited({ clientX, clientY }: { clientX: number; clientY: number }): void {
    handleMouseExited(clientX, clientY);
  }
}

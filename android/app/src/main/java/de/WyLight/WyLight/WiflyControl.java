/**
                Copyright (C) 2012 - 2014 Patrick Bruenn.

    This file is part of WyLight.

    Wylight is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    WiflyLight is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with WiflyLight.  If not, see <http://www.gnu.org/licenses/>. */

package de.WyLight.WyLight;

import de.WyLight.WyLight.exception.ConnectionTimeout;
import de.WyLight.WyLight.exception.FatalError;
import de.WyLight.WyLight.exception.ScriptBufferFull;
import de.WyLight.WyLight.library.Endpoint;
import de.WyLight.WyLight.library.ScriptAdapter;

public class WiflyControl {

	public static final int ALL_LEDS = 0xffffffff;

	private native String ConfGetDeviceId(long pNative);

	private native String ConfGetPassphrase(long pNative);

	private native boolean ConfGetSoftAp(long pNative);

	private native String ConfGetSsid(long pNative);

	private native boolean ConfSetWlan(long pNative, String passphrase,
			String ssid, String deviceId, boolean softAp);

	private native boolean FwClearScript(long pNative);

	private native boolean FwLoopOff(long pNative, byte numLoops);

	private native boolean FwLoopOn(long pNative);

	private native boolean FwSendScript(long pNative, long pNativeScript)
			throws ConnectionTimeout, FatalError, ScriptBufferFull;

	private native boolean FwSetColor(long pNative, int argb, int addr)
			throws ConnectionTimeout, FatalError, ScriptBufferFull;

	private native boolean FwSetFade(long pNative, int argb, int addr,
			short fadeTime) throws ConnectionTimeout, FatalError,
			ScriptBufferFull;

	private native boolean FwSetGradient(long pNative, int argb_1, int argb_2,
			int length, int offset, short fadeTime) throws ConnectionTimeout,
			FatalError, ScriptBufferFull;

	private native void release(long pNative);

	private native void Startup(long pNative, String path);

	public interface StartupListener {
		void setMessage(String message);
	}

	private StartupListener mListener = null;
	private long mNative;

	WiflyControl() {
		this(null);
	}

	WiflyControl(StartupListener listener) {
		mListener = listener;
	}

	public void finalize() throws Throwable {
		disconnect();
	}

	public synchronized void connect(Endpoint remote) throws FatalError {
		mNative = remote.connect();
	}

	public synchronized void disconnect() {
		release(mNative);
		mNative = 0;
	}

	public synchronized String confGetDeviceId() {
		return ConfGetDeviceId(mNative);
	}

	public synchronized String confGetPassphrase() {
		return ConfGetPassphrase(mNative);
	}

	public synchronized boolean confGetSoftAp() {
		return ConfGetSoftAp(mNative);
	}

	public synchronized String confGetSsid() {
		return ConfGetSsid(mNative);
	}

	public synchronized boolean confSetWlan(String passphrase, String ssid,
			String deviceId, boolean softAp) {
		return ConfSetWlan(mNative, passphrase, ssid, deviceId, softAp);
	}

	public synchronized boolean fwClearScript() {
		return FwClearScript(mNative);
	}

	public synchronized boolean fwLoopOff(byte numLoops) {
		return FwLoopOff(mNative, numLoops);
	}

	public synchronized boolean fwLoopOn() {
		return FwLoopOn(mNative);
	}

	public synchronized void fwSendScript(ScriptAdapter script)
			throws ConnectionTimeout, ScriptBufferFull, FatalError {
		FwSendScript(mNative, script.getNative());
	}

	public synchronized boolean fwSetColor(int argb, int addr)
			throws ConnectionTimeout, FatalError, ScriptBufferFull {
		return FwSetColor(mNative, argb, addr);
	}

	public synchronized boolean fwSetFade(int argb, int addr, short fadeTime)
			throws ConnectionTimeout, FatalError, ScriptBufferFull {
		return FwSetFade(mNative, argb, addr, fadeTime);
	}

	public synchronized boolean fwSetGradient(int argb_1, int argb_2,
			int length, int offset, short fadeTime) throws ConnectionTimeout,
			FatalError, ScriptBufferFull {
		return FwSetGradient(mNative, argb_1, argb_2, length, offset, fadeTime);
	}

	public synchronized void startup(Endpoint remote, String path,
			StartupListener listener) throws FatalError {
		mListener = listener;
		try {
			connect(remote);
			Startup(mNative, path);
			mListener = null;
		} catch (FatalError e) {
			listener.setMessage(e.getLocalizedMessage());
			mListener = null;
			throw e;
		}
	}

	public void startupCallback(String message) {
		if (null != mListener) {
			mListener.setMessage(message);
		}
	}
}

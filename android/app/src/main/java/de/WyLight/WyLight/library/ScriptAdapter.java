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

package de.WyLight.WyLight.library;

import de.WyLight.WyLight.FadeTime;
import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.util.DisplayMetrics;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.BaseAdapter;
import android.widget.TextView;

public class ScriptAdapter extends BaseAdapter {

	private native void addFade(long pNative, int argb, int addr, short fadeTime);

	private native void addGradient(long pNative, int argb_1, int argb_2,
			short fadeTime);

	private native void clear(long pNative);

	private native long create(String filename);

	private native long getItem(long pNative, int position);

	private native String name(long pNative);

	private native int numCommands(long pNative);

	private final long mNative;
	public boolean mDesignatedForDeletion = false;

	public ScriptAdapter(long pNative) {
		mNative = pNative;
	}

	ScriptAdapter(String filename) {
		mNative = create(filename);
	}

	public void addFade(int argb, int addr, short fadeTime) {
		addFade(mNative, argb, addr, fadeTime);
		notifyDataSetChanged();
	}

	public void addGradient(int argb_1, int argb_2, short fadeTime) {
		addGradient(mNative, argb_1, argb_2, fadeTime);
		notifyDataSetChanged();
	}

	public void clear() {
		clear(mNative);
		notifyDataSetChanged();
	}

	private int[] getColors() {
		final int count = getCount();
		switch (count) {
		case 0:
			return new int[] {Color.DKGRAY, Color.BLACK, Color.DKGRAY};
		case 1:
			final int c = getItem(0).getColor();
			return new int[] {c, c};
		default:
			int[] colors = new int[count];
			for (int i = 0; i < colors.length; ++i) {
				colors[i] = getItem(i).getColor();
			}
			return colors;
		}
	}

	public int getCount() {
		return numCommands(mNative);
	}

	public FwCmdScriptAdapter getItem(int position) {
		return new FwCmdScriptAdapter(getItem(mNative, position));
	}

	public long getItemId(int position) {
		return getItem(mNative, position);
	}

	public String getName() {
		return name(mNative);
	}

	public long getNative() {
		return mNative;
	}

	public View getView(int position, View convertView, ViewGroup parent) {
		final FwCmdScriptAdapter item = getItem(position);
		switch (item.getType()) {
		case FADE:
			return getView(item, parent.getContext(),
					getFadeBackground(item, position));
		case GRADIENT:
			return getView(item, parent.getContext(),
					getGradientBackground(item));
		default:
			TextView v = new TextView(parent.getContext());
			v.setText("no " + item.getType() + " view available");
			return v;
		}
	}

	private View getView(FwCmdScriptAdapter item, Context context,
			GradientDrawable d) {
		WindowManager wm = (WindowManager) context
				.getSystemService(Context.WINDOW_SERVICE);
		DisplayMetrics metrics = new DisplayMetrics();
		wm.getDefaultDisplay().getMetrics(metrics);
		TextView v = new TextView(context);
		final float factor = FadeTime.timeToScaling(item.getTime());
		v.setHeight((int) (factor * metrics.xdpi));
		v.setWidth(metrics.widthPixels);
		d.setShape(GradientDrawable.RECTANGLE);
		d.setCornerRadius(30);
		v.setBackgroundDrawable(d);
		return v;
	}

	public View getView(Context context) {
		final WindowManager wm = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
		final DisplayMetrics metrics = new DisplayMetrics();
		wm.getDefaultDisplay().getMetrics(metrics);
		final int height = (int) (0.5f * metrics.xdpi);

		final GradientDrawable background = new GradientDrawable(
				GradientDrawable.Orientation.LEFT_RIGHT, getColors());
		background.setCornerRadius(15);

		final TextView v = new TextView(context);
		v.setHeight(height);
		v.setWidth(metrics.widthPixels);
		v.setBackgroundDrawable(background);
		return v;
	}

	private GradientDrawable getFadeBackground(FwCmdScriptAdapter item,
			final int position) {
		final int topColor = (position <= 0) ? Color.BLACK : getItem(
				position - 1).getColor();
		final int bottomColor = item.getColor();
		final int colors[] = new int[] { topColor, bottomColor };
		return new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
				colors);
	}

	private GradientDrawable getGradientBackground(FwCmdScriptAdapter item) {
		final int colors[] = item.getGradientColor();
		return new GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT,
				colors);
	}
}

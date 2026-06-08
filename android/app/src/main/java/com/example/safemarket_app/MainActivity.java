package com.example.safemarket_app;

import android.graphics.Color;
import android.os.Bundle;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        getWindow().setBackgroundDrawableResource(android.R.color.white);
        getWindow().getDecorView().setBackgroundColor(Color.WHITE);
        super.onCreate(savedInstanceState);
    }
}
